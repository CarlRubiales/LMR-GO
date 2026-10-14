import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/delivery_request.dart';
import '../services/mock_backend.dart';
import '../services/offline_queue_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page.dart';
import '../widgets/eod_return_sheet.dart';
import '../widgets/hub_pickup_sheet.dart';
import '../widgets/parcel_card.dart';
import '../widgets/route_map_view.dart';
import '../widgets/stop_details_sheet.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({
    super.key,
    this.activeTrip,
    this.stage = DeliveryStage.accepted,
    this.onAccept,
    this.onProgress,
    this.onMessageHub,
  });

  final DeliveryRequest? activeTrip;
  final DeliveryStage stage;
  final ValueChanged<DeliveryRequest>? onAccept;
  final VoidCallback? onProgress;
  final ValueChanged<String>? onMessageHub;

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  // 0: To Load, 1: Out for Delivery, 2: Delivered, 3: Failed/Rescheduled
  int _activeTab = 0;
  bool _isMapView = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<DeliveryRequest> _allParcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParcels();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    final parcels = await MockBackend().getTodayRunParcels();
    // Sort in route order (nearest-next)
    final sorted = List<DeliveryRequest>.from(parcels)
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

    if (mounted) {
      setState(() {
        _allParcels = sorted;
        _isLoading = false;
      });
    }
  }

  List<DeliveryRequest> get _filteredParcels {
    List<DeliveryRequest> base;
    switch (_activeTab) {
      case 0: // To Load
        base = _allParcels.where((p) => p.stage == DeliveryStage.accepted).toList();
        break;
      case 1: // Out for Delivery
        base = _allParcels.where((p) {
          return p.stage == DeliveryStage.pickedUp ||
              p.stage == DeliveryStage.outForDelivery ||
              p.stage == DeliveryStage.arrived;
        }).toList();
        break;
      case 2: // Delivered
        base = _allParcels.where((p) {
          return p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed;
        }).toList();
        break;
      case 3: // Failed / Rescheduled
      default:
        base = _allParcels.where((p) {
          return p.stage == DeliveryStage.failed ||
              p.stage == DeliveryStage.rescheduled ||
              p.stage == DeliveryStage.returningToHub ||
              p.stage == DeliveryStage.returnedToHub;
        }).toList();
        break;
    }

    if (_searchQuery.isEmpty) return base;

    return base.where((p) {
      return p.id.toLowerCase().contains(_searchQuery) ||
          p.receiverName.toLowerCase().contains(_searchQuery) ||
          p.deliveryArea.toLowerCase().contains(_searchQuery) ||
          (p.barcode != null && p.barcode!.toLowerCase().contains(_searchQuery)) ||
          p.receiverAddress.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  int _countForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _allParcels.where((p) => p.stage == DeliveryStage.accepted).length;
      case 1:
        return _allParcels.where((p) {
          return p.stage == DeliveryStage.pickedUp ||
              p.stage == DeliveryStage.outForDelivery ||
              p.stage == DeliveryStage.arrived;
        }).length;
      case 2:
        return _allParcels.where((p) {
          return p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed;
        }).length;
      case 3:
      default:
        return _allParcels.where((p) {
          return p.stage == DeliveryStage.failed ||
              p.stage == DeliveryStage.rescheduled ||
              p.stage == DeliveryStage.returningToHub ||
              p.stage == DeliveryStage.returnedToHub;
        }).length;
    }
  }

  void _openStopDetails(DeliveryRequest parcel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StopDetailsSheet(
        parcel: parcel,
        totalStops: _allParcels.length,
        onStatusChanged: _loadParcels,
        onMessageHub: widget.onMessageHub,
      ),
    );
  }

  void _openHubPickup() {
    final toLoad = _allParcels.where((p) => p.stage == DeliveryStage.accepted).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HubPickupSheet(
        assignedParcels: toLoad.isNotEmpty ? toLoad : _allParcels,
        onRunStarted: () {
          _loadParcels();
          setState(() => _activeTab = 1); // Auto switch to Out for Delivery tab
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
        allParcels: _allParcels,
        onComplete: _loadParcels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toLoadCount = _countForTab(0);
    final outCount = _countForTab(1);
    final deliveredCount = _countForTab(2);
    final failedCount = _countForTab(3);

    return AppPage(
      title: 'Deliveries',
      subtitle: 'Manage your route, stops & proof of delivery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline Queue Banner (if any updates are pending sync)
          ValueListenableBuilder<int>(
            valueListenable: OfflineQueueService.instance.pendingCount,
            builder: (context, pending, _) {
              if (pending == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pendingSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: AppColors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$pending status update${pending > 1 ? "s" : ""} queued offline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => OfflineQueueService.instance.flushQueue(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.plum,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sync',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Primary Stage Action Banner
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blush1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toLoadCount > 0
                            ? '$toLoadCount awaiting load'
                            : outCount > 0
                                ? '$outCount active stops'
                                : 'All stops processed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sorting Center Bins',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (toLoadCount > 0)
                  FilledButton.icon(
                    onPressed: _openHubPickup,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.plum,
                      foregroundColor: AppColors.cream,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 14),
                    label: Text(
                      'Load Parcels',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _openEodReturn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.plum,
                      side: const BorderSide(color: AppColors.plum),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.assignment_return_outlined, size: 14),
                    label: Text(
                      'End of Day',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // 4 Sub-Tabs: To Load, Out for Delivery, Delivered, Failed/Rescheduled
          Container(
            decoration: BoxDecoration(
              color: AppColors.blush1,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildTabItem(0, 'To Load', toLoadCount),
                _buildTabItem(1, 'Active', outCount),
                _buildTabItem(2, 'Delivered', deliveredCount),
                _buildTabItem(3, 'Failed', failedCount),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Bar + List/Map Toggle Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search parcel ID or receiver...',
                      hintStyle: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Toggle between List and Route Map View
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'List view',
                      icon: Icon(
                        Icons.view_list,
                        size: 20,
                        color: !_isMapView ? AppColors.plum : AppColors.muted,
                      ),
                      onPressed: () => setState(() => _isMapView = false),
                    ),
                    IconButton(
                      tooltip: 'Route map view',
                      icon: Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: _isMapView ? AppColors.plum : AppColors.muted,
                      ),
                      onPressed: () => setState(() => _isMapView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Content: List View or Route Map View
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.plum),
              ),
            )
          else if (_isMapView)
            SizedBox(
              height: 420,
              child: RouteMapView(
                parcels: _allParcels,
                onSelectStop: _openStopDetails,
              ),
            )
          else ...[
            if (_filteredParcels.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      _activeTab == 2
                          ? Icons.check_circle_outline
                          : _activeTab == 3
                              ? Icons.thumb_up_alt_outlined
                              : Icons.inventory_2_outlined,
                      size: 40,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No parcels match "$_searchQuery"'
                          : _activeTab == 0
                              ? 'No parcels pending hub load.'
                              : _activeTab == 1
                                  ? 'No active stops out for delivery.'
                                  : _activeTab == 2
                                      ? 'No parcels marked delivered yet.'
                                      : 'No delivery exceptions recorded.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _filteredParcels.map((parcel) {
                  return ParcelCard(
                    parcel: parcel,
                    onTap: () => _openStopDetails(parcel),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, int count) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.cream : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.plum.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: isSelected ? AppColors.plum : AppColors.muted,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blush1 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    color: isSelected ? AppColors.plum : AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
