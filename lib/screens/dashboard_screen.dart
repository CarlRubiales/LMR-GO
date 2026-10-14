import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/delivery_request.dart';
import '../services/mock_backend.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page.dart';
import '../widgets/eod_return_sheet.dart';
import '../widgets/hub_pickup_sheet.dart';
import '../widgets/parcel_card.dart';
import '../widgets/stop_details_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.available,
    required this.onAvailability,
    required this.activeTrip,
    required this.onAccept,
    required this.onTab,
    required this.onAccount,
    required this.registered,
    this.onLoadParcels,
    this.onMessageHub,
  });

  final bool available;
  final ValueChanged<bool> onAvailability;
  final DeliveryRequest? activeTrip;
  final ValueChanged<DeliveryRequest> onAccept;
  final ValueChanged<int> onTab;
  final VoidCallback onAccount;
  final bool registered;
  final VoidCallback? onLoadParcels;
  final ValueChanged<String>? onMessageHub;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0: All, 1: Assigned, 2: In Transit, 3: Delivered, 4: Failed, 5: Rescheduled
  int _statusFilter = 0;
  List<DeliveryRequest> _parcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshParcels();
  }

  Future<void> _refreshParcels() async {
    setState(() => _isLoading = true);
    final data = await MockBackend().getTodayRunParcels();
    final sorted = List<DeliveryRequest>.from(data)
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

    if (mounted) {
      setState(() {
        _parcels = sorted;
        _isLoading = false;
      });
    }
  }

  DeliveryRequest? get _nextStop {
    // Look for first outForDelivery or arrived parcel in stopOrder
    final active = _parcels.where(
      (p) => p.stage == DeliveryStage.outForDelivery || p.stage == DeliveryStage.arrived,
    );
    if (active.isNotEmpty) return active.first;

    // Otherwise next assigned or picked up
    final pending = _parcels.where(
      (p) => p.stage == DeliveryStage.accepted || p.stage == DeliveryStage.pickedUp,
    );
    if (pending.isNotEmpty) return pending.first;

    return null;
  }

  Future<void> _launchMaps(String address) async {
    final query = Uri.encodeComponent('$address, Philippines');
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openStopDetails(DeliveryRequest parcel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StopDetailsSheet(
        parcel: parcel,
        totalStops: _parcels.length,
        onStatusChanged: _refreshParcels,
        onMessageHub: (parcelId) {
          if (widget.onMessageHub != null) {
            widget.onMessageHub!(parcelId);
          } else {
            widget.onTab(2);
          }
        },
      ),
    );
  }

  void _openHubPickup() {
    final toLoad = _parcels.where((p) => p.stage == DeliveryStage.accepted).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HubPickupSheet(
        assignedParcels: toLoad.isNotEmpty ? toLoad : _parcels,
        onRunStarted: () {
          _refreshParcels();
          widget.onTab(1); // Jump to Deliveries tab
        },
      ),
    );
  }

  void _openEodReturn() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EodReturnSheet(
        allParcels: _parcels,
        onComplete: _refreshParcels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedCount = _parcels.where((p) => p.stage == DeliveryStage.accepted).length;
    final pickedUpCount = _parcels.where((p) => p.stage == DeliveryStage.pickedUp).length;
    final outForDeliveryCount = _parcels
        .where((p) => p.stage == DeliveryStage.outForDelivery || p.stage == DeliveryStage.arrived)
        .length;
    final deliveredCount = _parcels
        .where((p) => p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed)
        .length;
    final failedCount = _parcels.where((p) => p.stage == DeliveryStage.failed).length;
    final rescheduledCount = _parcels.where((p) => p.stage == DeliveryStage.rescheduled).length;

    // Filtered manifest
    final filtered = switch (_statusFilter) {
      1 => _parcels.where((p) => p.stage == DeliveryStage.accepted).toList(),
      2 => _parcels.where((p) => p.stage == DeliveryStage.pickedUp).toList(),
      3 => _parcels
          .where((p) => p.stage == DeliveryStage.outForDelivery || p.stage == DeliveryStage.arrived)
          .toList(),
      4 => _parcels
          .where((p) => p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed)
          .toList(),
      5 => _parcels.where((p) => p.stage == DeliveryStage.failed).toList(),
      6 => _parcels.where((p) => p.stage == DeliveryStage.rescheduled).toList(),
      _ => _parcels,
    };

    // Calculate total COD collected today to remit
    final totalCodCollected = _parcels
        .where((p) => p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed)
        .fold(0.0, (sum, p) => sum + (p.isCod ? p.codAmount : 0.0));

    final nextStop = _nextStop;

    return AppPage(
      title: "Today's Run",
      subtitle: 'Central Sorting Hub · Last-Mile Delivery Manifest',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Online / Offline Status & Assigned Areas Top Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.plum.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: widget.available ? AppColors.deliveredSoft : AppColors.blush1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.available ? Icons.radar : Icons.power_settings_new,
                        color: widget.available ? AppColors.delivered : AppColors.muted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.available ? AppColors.delivered : AppColors.muted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.available ? 'Rider Online' : 'Rider Offline',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.plum,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.available
                                ? 'Active for dispatch & parcel loading'
                                : 'Switch online to sync with logistics hub',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.available,
                      activeThumbColor: AppColors.orange,
                      activeTrackColor: AppColors.blush2,
                      onChanged: widget.onAvailability,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 10),
                // Rider's assigned areas tag
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Assigned Areas: San Juan · Mandaluyong · Pasig',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.plum,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.blush1,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Route MNL-4',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Operational Alerts Banner (New assignments, rescheduled, unread chat)
          if (rescheduledCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.pendingSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alert: $rescheduledCount parcel rescheduled for next delivery window.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _statusFilter = 6),
                    child: Text(
                      'Review',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.plum,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. One Big Primary Stage CTA Button
          _buildStageHeroButton(
            assignedCount: assignedCount,
            pickedUpCount: pickedUpCount,
            outCount: outForDeliveryCount,
            totalRemaining: assignedCount + pickedUpCount + outForDeliveryCount,
            nextStop: nextStop,
          ),
          const SizedBox(height: 16),

          // 4. "Next Stop" Hero Card (with Navigate and Stop Details)
          if (nextStop != null && (outForDeliveryCount > 0 || assignedCount > 0 || pickedUpCount > 0)) ...[
            _buildNextStopCard(nextStop),
            const SizedBox(height: 16),
          ],

          // 5. Today's Summary Cards (2 rows of 3 columns for 6 statuses)
          Text(
            'TODAY\'S PARCEL COUNTS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.plum,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _CountCard(
                  label: 'Assigned',
                  count: assignedCount,
                  color: AppColors.orange,
                  bg: AppColors.pendingSoft,
                  icon: Icons.inventory_2_outlined,
                  isSelected: _statusFilter == 1,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 1 ? 0 : 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountCard(
                  label: 'Picked Up',
                  count: pickedUpCount,
                  color: AppColors.inTransit,
                  bg: AppColors.inTransitSoft,
                  icon: Icons.local_shipping_outlined,
                  isSelected: _statusFilter == 2,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 2 ? 0 : 2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountCard(
                  label: 'Out for Delivery',
                  count: outForDeliveryCount,
                  color: AppColors.inTransit,
                  bg: AppColors.inTransitSoft,
                  icon: Icons.navigation_outlined,
                  isSelected: _statusFilter == 3,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 3 ? 0 : 3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _CountCard(
                  label: 'Delivered',
                  count: deliveredCount,
                  color: AppColors.delivered,
                  bg: AppColors.deliveredSoft,
                  icon: Icons.check_circle_outline,
                  isSelected: _statusFilter == 4,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 4 ? 0 : 4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountCard(
                  label: 'Failed',
                  count: failedCount,
                  color: AppColors.failed,
                  bg: AppColors.failedSoft,
                  icon: Icons.cancel_outlined,
                  isSelected: _statusFilter == 5,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 5 ? 0 : 5),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountCard(
                  label: 'Rescheduled',
                  count: rescheduledCount,
                  color: AppColors.failed,
                  bg: AppColors.failedSoft,
                  icon: Icons.update_outlined,
                  isSelected: _statusFilter == 6,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 6 ? 0 : 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6. COD Remittance Section (Cash handling total to remit)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blush1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_outlined, color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COD CASH TO REMIT TODAY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₱${totalCodCollected.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.plum,
                        ),
                      ),
                      Text(
                        'Collected from delivered parcels',
                        style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _openEodReturn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.plum,
                    side: const BorderSide(color: AppColors.plum),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Remit',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 7. Assigned Parcel Manifest List
          SectionHeader(
            title: 'Run Manifest (${_parcels.length})',
            action: _statusFilter != 0 ? 'Show all' : null,
            onTap: () => setState(() => _statusFilter = 0),
          ),
          const SizedBox(height: 8),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All (${_parcels.length})',
                  isSelected: _statusFilter == 0,
                  onTap: () => setState(() => _statusFilter = 0),
                ),
                _FilterChip(
                  label: 'Assigned ($assignedCount)',
                  isSelected: _statusFilter == 1,
                  onTap: () => setState(() => _statusFilter = 1),
                ),
                _FilterChip(
                  label: 'Out for Delivery ($outForDeliveryCount)',
                  isSelected: _statusFilter == 3,
                  onTap: () => setState(() => _statusFilter = 3),
                ),
                _FilterChip(
                  label: 'Delivered ($deliveredCount)',
                  isSelected: _statusFilter == 4,
                  onTap: () => setState(() => _statusFilter = 4),
                ),
                _FilterChip(
                  label: 'Exceptions (${failedCount + rescheduledCount})',
                  isSelected: _statusFilter == 5 || _statusFilter == 6,
                  onTap: () => setState(() => _statusFilter = 5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Parcel cards list or Empty state
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.plum),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.muted),
                  const SizedBox(height: 8),
                  Text(
                    'No parcels in this status',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filtered.map(
              (parcel) => ParcelCard(
                parcel: parcel,
                onTap: () => _openStopDetails(parcel),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Big primary stage action button that changes with rider's workflow stage
  Widget _buildStageHeroButton({
    required int assignedCount,
    required int pickedUpCount,
    required int outCount,
    required int totalRemaining,
    required DeliveryRequest? nextStop,
  }) {
    // Stage 1: Parcels awaiting load at hub
    if (assignedCount > 0) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.plum, Color(0xFF532453)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warehouse_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CENTRAL SORTING HUB · BAY A-04',
                        style: GoogleFonts.inter(
                          color: AppColors.blush2,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '$assignedCount parcels ready for loading',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _openHubPickup,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cream,
                  foregroundColor: AppColors.plum,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(
                  'Go to Hub / Load Parcels',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Stage 2: Loaded parcels ready to depart hub
    if (pickedUpCount > 0 && outCount == 0) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.two_wheeler, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALL PARCELS LOADED',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '$pickedUpCount stops ready on route',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () async {
                  final toStart = _parcels
                      .where((p) => p.stage == DeliveryStage.pickedUp)
                      .map((p) => p.id)
                      .toList();
                  await MockBackend().startDeliveryRun(toStart);
                  _refreshParcels();
                  widget.onTab(1); // Jump to Deliveries
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.navigation, size: 18),
                label: Text(
                  'Start Delivery Run',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Stage 3: Active delivery run in progress
    if (outCount > 0 && nextStop != null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.plum,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DELIVERY RUN IN PROGRESS',
                        style: GoogleFonts.inter(
                          color: AppColors.blush2,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '$outCount stops remaining · Next: Stop #${nextStop.stopOrder}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _openStopDetails(nextStop),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cream,
                  foregroundColor: AppColors.plum,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.place, size: 18),
                label: Text(
                  'Continue Delivery (Stop #${nextStop.stopOrder})',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Stage 4: Run finished -> Return parcels / End of Day
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blush1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blush2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_return_outlined, color: AppColors.plum, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERY RUN COMPLETED',
                      style: GoogleFonts.inter(
                        color: AppColors.plum,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Ready for hub return intake & remittance',
                      style: GoogleFonts.inter(
                        color: AppColors.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _openEodReturn,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.plum,
                foregroundColor: AppColors.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Return Parcels to Hub',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Next Stop" Card showing receiver, address, landmark, ETA, COD, and Navigate button
  Widget _buildNextStopCard(DeliveryRequest parcel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Stop Badge + ETA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.plum,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'STOP #${parcel.stopOrder}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${parcel.distance} · ${parcel.eta}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Receiver name and COD
          Row(
            children: [
              Expanded(
                child: Text(
                  parcel.receiverName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.plum,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: parcel.isCod ? AppColors.blush1 : AppColors.deliveredSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: parcel.isCod ? AppColors.orange : AppColors.deliveredSoft,
                  ),
                ),
                child: Text(
                  parcel.formattedCod,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: parcel.isCod ? AppColors.orange : AppColors.delivered,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Address & Landmark
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.plum),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcel.receiverAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (parcel.landmark != null && parcel.landmark!.isNotEmpty)
                      Text(
                        'Landmark: ${parcel.landmark}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Navigate + Stop Details
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _launchMaps(parcel.receiverAddress),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.plum,
                    side: const BorderSide(color: AppColors.plum),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.navigation_outlined, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Navigate',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _openStopDetails(parcel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.plum,
                    foregroundColor: AppColors.cream,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Stop Details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  final String label;
  final int count;
  final Color color;
  final Color bg;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.plum : AppColors.cream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.plum : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.cream : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
