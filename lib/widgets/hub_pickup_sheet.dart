import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/delivery_request.dart';
import '../services/mock_backend.dart';
import '../theme/app_colors.dart';

class HubPickupSheet extends StatefulWidget {
  const HubPickupSheet({
    super.key,
    required this.assignedParcels,
    required this.onRunStarted,
  });

  final List<DeliveryRequest> assignedParcels;
  final VoidCallback onRunStarted;

  @override
  State<HubPickupSheet> createState() => _HubPickupSheetState();
}

class _HubPickupSheetState extends State<HubPickupSheet> {
  final TextEditingController _barcodeController = TextEditingController();
  final Set<String> _scannedParcelIds = <String>{};
  bool _isCameraActive = true;

  @override
  void initState() {
    super.initState();
    // Pre-mark any parcel already picked up
    for (final p in widget.assignedParcels) {
      if (p.stage != DeliveryStage.accepted) {
        _scannedParcelIds.add(p.id);
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _processBarcode(String rawBarcode) {
    final code = rawBarcode.trim();
    if (code.isEmpty) return;

    _barcodeController.clear();

    // Search for match in assigned parcels
    final match = widget.assignedParcels.where(
      (p) =>
          p.id.equalsIgnoreCase(code) ||
          (p.barcode != null && p.barcode!.equalsIgnoreCase(code)) ||
          (p.trackingNumber != null && p.trackingNumber!.equalsIgnoreCase(code)),
    );

    if (match.isEmpty) {
      // Barcode is NOT assigned to this rider! Show prominent warning alert
      _showNotAssignedWarning(code);
    } else {
      final parcel = match.first;
      if (_scannedParcelIds.contains(parcel.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcel ${parcel.id} is already loaded in your checklist.'),
            backgroundColor: AppColors.plum,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _scannedParcelIds.add(parcel.id);
        });
        MockBackend().updateParcelStatus(parcel.id, DeliveryStage.pickedUp);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${parcel.id} · ${parcel.receiverName}'),
            backgroundColor: AppColors.delivered,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  void _showNotAssignedWarning(String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.failed, width: 2),
        ),
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.failedSoft,
          child: Icon(Icons.warning_amber_rounded, color: AppColors.failed, size: 36),
        ),
        title: Text(
          'Parcel Not Assigned to You!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.failed,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.blush1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Barcode: $code',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.plum,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This parcel is not in your manifest for Today\'s Run. Do NOT load it onto your vehicle. Please hand it back to the Sorting Hub Coordinator.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.ink,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.plum,
                foregroundColor: AppColors.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Understood · Return to Hub Bin',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startRun() async {
    final toStart = _scannedParcelIds.toList();
    if (toStart.isEmpty) return;

    await MockBackend().startDeliveryRun(toStart);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onRunStarted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery Run Started! ${toStart.length} parcels out for delivery.'),
          backgroundColor: AppColors.delivered,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannedCount = _scannedParcelIds.length;
    final totalCount = widget.assignedParcels.length;
    final missingCount = totalCount - scannedCount;

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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hub Parcel Loading',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scan assigned barcodes before departing hub',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Checklist Stats Counters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.deliveredSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.delivered.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.delivered, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$scannedCount SCANNED',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.delivered,
                              ),
                            ),
                            Text(
                              'Loaded on vehicle',
                              style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: missingCount > 0 ? AppColors.pendingSoft : AppColors.blush1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: missingCount > 0 ? AppColors.pending.withValues(alpha: 0.4) : AppColors.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          missingCount > 0 ? Icons.error_outline : Icons.done_all,
                          color: missingCount > 0 ? AppColors.pending : AppColors.plum,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$missingCount MISSING',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: missingCount > 0 ? AppColors.pending : AppColors.plum,
                              ),
                            ),
                            Text(
                              'Still in hub bins',
                              style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barcode Viewfinder / Simulation Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161A22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: AppColors.cream, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'BARCODE / QR SCANNER',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isCameraActive = !_isCameraActive),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isCameraActive ? AppColors.delivered : Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isCameraActive ? 'READY' : 'PAUSED',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Manual Barcode Input and Scan Button
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _barcodeController,
                          onSubmitted: _processBarcode,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter barcode or parcel ID...',
                            hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _processBarcode(_barcodeController.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.plum,
                        foregroundColor: AppColors.cream,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Scan'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Scan Simulation Chips (convenient for testing and one-tap outdoor scanning)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final p in widget.assignedParcels)
                      ActionChip(
                        label: Text(
                          p.barcode ?? p.id,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _scannedParcelIds.contains(p.id) ? AppColors.delivered : Colors.white,
                          ),
                        ),
                        backgroundColor: _scannedParcelIds.contains(p.id)
                            ? AppColors.deliveredSoft.withValues(alpha: 0.2)
                            : Colors.white12,
                        side: BorderSide(
                          color: _scannedParcelIds.contains(p.id) ? AppColors.delivered : Colors.white24,
                        ),
                        avatar: Icon(
                          _scannedParcelIds.contains(p.id) ? Icons.check : Icons.barcode_reader,
                          size: 13,
                          color: _scannedParcelIds.contains(p.id) ? AppColors.delivered : Colors.white70,
                        ),
                        onPressed: () => _processBarcode(p.barcode ?? p.id),
                      ),
                    // Also a simulated invalid parcel button to test the warning alert
                    ActionChip(
                      label: Text(
                        'UNKNOWN-999',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.failed,
                        ),
                      ),
                      backgroundColor: AppColors.failedSoft.withValues(alpha: 0.2),
                      side: const BorderSide(color: AppColors.failed),
                      avatar: const Icon(Icons.warning, size: 12, color: AppColors.failed),
                      onPressed: () => _processBarcode('UNKNOWN-999'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Checklist of Parcels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'MANIFEST CHECKLIST',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.plum,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final p in widget.assignedParcels) {
                        _scannedParcelIds.add(p.id);
                        MockBackend().updateParcelStatus(p.id, DeliveryStage.pickedUp);
                      }
                    });
                  },
                  child: Text(
                    'Scan All in Bin',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Parcel checklist scrollable list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: widget.assignedParcels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = widget.assignedParcels[index];
                final isScanned = _scannedParcelIds.contains(p.id);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isScanned ? AppColors.deliveredSoft.withValues(alpha: 0.3) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isScanned ? AppColors.delivered : AppColors.line,
                      width: isScanned ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isScanned ? AppColors.delivered : AppColors.blush1,
                        child: Icon(
                          isScanned ? Icons.check : Icons.inventory_2_outlined,
                          size: 14,
                          color: isScanned ? Colors.white : AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.id,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.plum,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.pickup,
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.receiverName} · ${p.deliveryArea}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            p.formattedCod,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: p.isCod ? AppColors.orange : AppColors.delivered,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isScanned ? 'READY' : 'SCAN PENDING',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isScanned ? AppColors.delivered : AppColors.pending,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom "Start Delivery Run" Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: scannedCount > 0 ? _startRun : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  foregroundColor: AppColors.cream,
                  disabledBackgroundColor: AppColors.line,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.two_wheeler, size: 20),
                label: Text(
                  scannedCount > 0
                      ? 'Start Delivery Run ($scannedCount Loaded)'
                      : 'Scan Parcels to Start Run',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
