import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/delivery_request.dart';
import '../models/delivery_status.dart';
import '../services/mock_backend.dart';
import '../services/navigation_service.dart';
import '../theme/app_colors.dart';
import 'failed_delivery_sheet.dart';
import 'parcel_scanner_sheet.dart';
import 'pod_sheet.dart';

class StopDetailsSheet extends StatefulWidget {
  const StopDetailsSheet({
    super.key,
    required this.parcel,
    required this.totalStops,
    required this.onStatusChanged,
    this.onMessageHub,
  });

  final DeliveryRequest parcel;
  final int totalStops;
  final VoidCallback onStatusChanged;
  final ValueChanged<String>? onMessageHub;

  @override
  State<StopDetailsSheet> createState() => _StopDetailsSheetState();
}

class _StopDetailsSheetState extends State<StopDetailsSheet> {
  late DeliveryRequest _currentParcel;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentParcel = widget.parcel;
  }

  Future<void> _confirmItemInHand() async {
    setState(() => _isUpdating = true);
    try {
      await MockBackend().updateParcelStatus(
        _currentParcel.id,
        DeliveryStage.returningToHub,
        failureReason: _currentParcel.effectiveReturnReason,
        failureNotes: _currentParcel.effectiveReturnDetails,
      );
      setState(() {
        _currentParcel = _currentParcel.copyWith(
          stage: DeliveryStage.returningToHub,
          isReturnRefund: true,
        );
        _isUpdating = false;
      });
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item in hand confirmed for ${_currentParcel.id}. Hand in to hub when ready.'),
            backgroundColor: AppColors.plum,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.failed),
        );
      }
    }
  }

  Future<void> _confirmReturnedToHub() async {
    setState(() => _isUpdating = true);
    try {
      await MockBackend().updateParcelStatus(
        _currentParcel.id,
        DeliveryStage.returnedToHub,
        failureReason: _currentParcel.effectiveReturnReason,
        failureNotes: _currentParcel.effectiveReturnDetails,
      );
      setState(() {
        _currentParcel = _currentParcel.copyWith(
          stage: DeliveryStage.returnedToHub,
          isReturnRefund: true,
        );
        _isUpdating = false;
      });
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcel ${_currentParcel.id} handed in to hub. Return intake completed!'),
            backgroundColor: AppColors.delivered,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.failed),
        );
      }
    }
  }

  Future<void> _launchMaps() async {
    await NavigationService.navigateToAddress(
      context,
      address: _currentParcel.receiverAddress,
      name: _currentParcel.receiverName,
      landmark: _currentParcel.landmark,
    );
  }

  Future<void> _launchCall() async {
    final phone = _currentParcel.receiverPhone.replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return;

    final url = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showPhoneDialog(phone);
      }
    } catch (_) {
      _showPhoneDialog(phone);
    }
  }

  Future<void> _launchSms() async {
    final phone = _currentParcel.receiverPhone.replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return;

    final url = Uri.parse('sms:$phone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showPhoneDialog(phone);
      }
    } catch (_) {
      _showPhoneDialog(phone);
    }
  }

  void _showPhoneDialog(String phone) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('Customer Contact', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Call or SMS: $phone', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markOutForDelivery() async {
    await MockBackend().updateParcelStatus(_currentParcel.id, DeliveryStage.outForDelivery);
    setState(() {
      _currentParcel = _currentParcel.copyWith(stage: DeliveryStage.outForDelivery);
    });
    widget.onStatusChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked OUT FOR DELIVERY. Ready to hand over parcel.'),
          backgroundColor: AppColors.inTransit,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openBarcodeScanner() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParcelScannerSheet(
        targetParcel: _currentParcel,
        onParcelScanned: (updated) {
          setState(() {
            _currentParcel = updated;
          });
          widget.onStatusChanged();
        },
      ),
    );
  }

  void _openPod() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PodSheet(
        parcel: _currentParcel,
        onDelivered: () {
          setState(() {
            _currentParcel = _currentParcel.copyWith(stage: DeliveryStage.delivered);
          });
          widget.onStatusChanged();
        },
      ),
    );
  }

  void _openFailed({bool isPostDelivery = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FailedDeliverySheet(
        parcel: _currentParcel,
        isPostDelivery: isPostDelivery,
        onFailedRecorded: () {
          final refreshed = MockBackend().parcelsNotifier.value.firstWhere(
            (p) => p.id == _currentParcel.id,
            orElse: () => _currentParcel,
          );
          setState(() {
            _currentParcel = refreshed;
          });
          widget.onStatusChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = DeliveryStatus.fromStage(_currentParcel.stage);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Stop Sequence + Status Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.plum,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'STOP #${_currentParcel.stopOrder} OF ${widget.totalStops}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentParcel.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: status.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: AppColors.line),

          // Body Details
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // Receiver Name & Contact Quick Actions Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentParcel.receiverName,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.plum,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentParcel.receiverPhone,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // COD Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: _currentParcel.isCod ? AppColors.blush1 : AppColors.deliveredSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _currentParcel.isCod ? AppColors.orange : AppColors.deliveredSoft,
                              ),
                            ),
                            child: Text(
                              _currentParcel.formattedCod,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _currentParcel.isCod ? AppColors.orange : AppColors.delivered,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Call, SMS, Navigate Big Outdoor Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _launchMaps,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.plum,
                                side: const BorderSide(color: AppColors.plum),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.navigation_outlined, size: 17),
                              label: Text(
                                'Navigate',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _launchCall,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.blush2,
                                foregroundColor: AppColors.plum,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.call, size: 17),
                              label: Text(
                                'Call',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _launchSms,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.blush2,
                                foregroundColor: AppColors.plum,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.sms_outlined, size: 17),
                              label: Text(
                                'SMS',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Delivery Address & Landmark
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.plum, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'DELIVERY ADDRESS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.plum,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentParcel.receiverAddress,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.3,
                        ),
                      ),
                      if (_currentParcel.landmark != null && _currentParcel.landmark!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.blush1,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me_outlined, size: 14, color: AppColors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Landmark: ${_currentParcel.landmark}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.plum,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Manifest & Sorting Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: AppColors.plum, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'PARCEL MANIFEST DETAILS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.plum,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tracking Barcode', style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted)),
                          InkWell(
                            onTap: _openBarcodeScanner,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentParcel.barcode ?? _currentParcel.id,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.plum,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.qr_code_scanner, size: 14, color: AppColors.orange),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Hub Pickup Bin', style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted)),
                          Text(
                            _currentParcel.pickup,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Payment Type', style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted)),
                          Text(
                            _currentParcel.isCod ? 'Cash on Delivery (COD)' : 'Prepaid by Shipper',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _currentParcel.isCod ? AppColors.orange : AppColors.delivered,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Shortcut: "Message hub about this parcel"
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (widget.onMessageHub != null) {
                      widget.onMessageHub!(_currentParcel.id);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Chat opened with parcel ${_currentParcel.id} attached.'),
                          backgroundColor: AppColors.plum,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.plum),
                  label: Text(
                    'Message hub about this parcel',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lifecycle Progression Outdoor Buttons (Big Touch Targets)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: _buildLifecycleActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleActions() {
    final stage = _currentParcel.stage;

    // Return & Refund Lifecycle Handling (2-Step Confirmation)
    if (_currentParcel.isReturnRefund) {
      if (stage == DeliveryStage.returnedToHub) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.deliveredSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.delivered),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.delivered, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Returned to Hub · Return Intake Recorded',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.delivered,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (stage == DeliveryStage.returningToHub) {
        // Step 2: Item in rider hands -> Confirm when parcel hands in into the hub!
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.blush1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.front_hand_outlined, size: 16, color: AppColors.plum),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Parcel is in your hands · Hand in to sorting hub',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isUpdating ? null : _confirmReturnedToHub,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.warehouse_outlined, size: 20),
                label: Text(
                  _isUpdating ? 'Handing in to Hub...' : 'Returned to Hub (Hand In)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _openFailed(isPostDelivery: true),
              icon: const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.muted),
              label: Text(
                'View Buyer Claim & Proof Details',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        );
      }

      // Step 1: Return approved by seller -> Rider confirms parcel is in his hands!
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.failedSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_return_outlined, size: 16, color: AppColors.failed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Return Approved by Seller · Collect item from buyer',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.failed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _isUpdating ? null : _confirmItemInHand,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.front_hand_outlined, size: 20),
              label: Text(
                _isUpdating ? 'Confirming...' : 'Confirm Item in Hand',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _openFailed(isPostDelivery: true),
            icon: const Icon(Icons.info_outline, size: 14, color: AppColors.plum),
            label: Text(
              'Inspect Buyer Return Reason & Proof',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.plum,
              ),
            ),
          ),
        ],
      );
    }

    // Stage 1A: Assigned at hub (not yet picked up) -> "Scan Barcode to Pick Up"
    if (stage == DeliveryStage.accepted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _openBarcodeScanner,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: Text(
                'Scan Barcode to Pick Up',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _markOutForDelivery,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.plum,
                side: const BorderSide(color: AppColors.plum),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: Text(
                'Mark Out for Delivery',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }

    // Stage 1B: Picked up at hub -> "Mark Out for Delivery"
    if (stage == DeliveryStage.pickedUp) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _markOutForDelivery,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.plum,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.navigation_outlined, size: 22),
          label: Text(
            'Mark Out for Delivery',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      );
    }

    // Stage 2: Out for delivery (or arrived) -> "Delivered" only (Full width green button)
    if (stage == DeliveryStage.outForDelivery || stage == DeliveryStage.arrived) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _openPod,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.delivered,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                'Delivered',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _openFailed(isPostDelivery: false),
            icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.muted),
            label: Text(
              'Unable to deliver? Report issue',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      );
    }

    // Stage 3: Already Delivered -> Show Completed Status AND "Return/Refund" button
    if (stage == DeliveryStage.delivered || stage == DeliveryStage.completed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.deliveredSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.delivered,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Delivery Completed · POD On File',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppColors.delivered,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _openFailed(isPostDelivery: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.failed,
                side: const BorderSide(color: AppColors.failed, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.assignment_return_outlined, size: 18),
              label: Text(
                'Return/Refund',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      );
    }

    // Stage 4: Returned to Hub
    if (stage == DeliveryStage.returnedToHub) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.blush1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warehouse_outlined,
              color: AppColors.plum,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Returned to Hub · Return Intake Recorded',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.plum,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Stage 5: Failed / Rescheduled / Return/Refund recorded
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.failedSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.assignment_return_outlined,
            color: AppColors.failed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Return/Refund Recorded (${_currentParcel.failureReason ?? "Pending Hub Review"})',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: AppColors.failed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

