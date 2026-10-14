import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/delivery_request.dart';
import '../services/mock_backend.dart';
import '../theme/app_colors.dart';

class EodReturnSheet extends StatefulWidget {
  const EodReturnSheet({
    super.key,
    required this.allParcels,
    required this.onComplete,
  });

  final List<DeliveryRequest> allParcels;
  final VoidCallback onComplete;

  @override
  State<EodReturnSheet> createState() => _EodReturnSheetState();
}

class _EodReturnSheetState extends State<EodReturnSheet> {
  final Set<String> _scannedReturnIds = <String>{};
  final TextEditingController _barcodeController = TextEditingController();

  List<DeliveryRequest> get _undeliveredParcels {
    return widget.allParcels.where((p) {
      return p.stage == DeliveryStage.failed ||
          p.stage == DeliveryStage.rescheduled ||
          p.stage == DeliveryStage.returningToHub ||
          p.stage == DeliveryStage.returnedToHub ||
          p.stage == DeliveryStage.accepted ||
          p.stage == DeliveryStage.pickedUp ||
          p.stage == DeliveryStage.outForDelivery ||
          p.stage == DeliveryStage.arrived;
    }).toList();
  }

  double get _totalCodCollected {
    return widget.allParcels
        .where((p) => p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed)
        .fold(0.0, (sum, p) => sum + (p.isCod ? p.codAmount : 0.0));
  }

  @override
  void initState() {
    super.initState();
    // Pre-mark any already marked as returnedToHub
    for (final p in _undeliveredParcels) {
      if (p.stage == DeliveryStage.returnedToHub) {
        _scannedReturnIds.add(p.id);
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _scanReturnBarcode(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;

    _barcodeController.clear();
    final match = _undeliveredParcels.where(
      (p) =>
          p.id.toLowerCase() == code.toLowerCase() ||
          (p.barcode != null && p.barcode!.toLowerCase() == code.toLowerCase()),
    );

    if (match.isNotEmpty) {
      final p = match.first;
      setState(() => _scannedReturnIds.add(p.id));
      MockBackend().returnParcelToHub(p.id, reason: 'End of day hub intake scan');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Returned ${p.id} to sorting intake bin.'),
          backgroundColor: AppColors.delivered,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parcel $code not found in undelivered list.'),
          backgroundColor: AppColors.failed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeIntake() async {
    for (final id in _scannedReturnIds) {
      await MockBackend().returnParcelToHub(id);
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End of Day intake complete! Parcels logged into hub.'),
          backgroundColor: AppColors.plum,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final undelivered = _undeliveredParcels;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
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
                      'End of Day Return & Remit',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hand over undelivered parcels & COD cash to hub cashier',
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
          const Divider(height: 18, color: AppColors.line),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // COD Remittance Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.blush1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: AppColors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'COD CASH TO REMIT TODAY',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₱${_totalCodCollected.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total cash collected from receivers today. Present this to Hub Cashier.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Undelivered Parcels Barcode Intake Scan
                Text(
                  'SCAN PARCELS BACK INTO HUB SORTING',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.plum,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _barcodeController,
                          onSubmitted: _scanReturnBarcode,
                          decoration: InputDecoration(
                            hintText: 'Enter barcode to scan back in...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.line),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _scanReturnBarcode(_barcodeController.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.plum,
                        foregroundColor: AppColors.cream,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Intake'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Undelivered / Return Checklist
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Undelivered Parcels (${_scannedReturnIds.length}/${undelivered.length} Scanned In)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.plum),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (final p in undelivered) {
                            _scannedReturnIds.add(p.id);
                          }
                        });
                      },
                      child: const Text('Return All to Hub'),
                    ),
                  ],
                ),

                if (undelivered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: Text(
                      'All parcels were successfully delivered today! 🎉',
                      style: GoogleFonts.inter(
                        color: AppColors.delivered,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  for (final p in undelivered) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _scannedReturnIds.contains(p.id) ? AppColors.deliveredSoft.withValues(alpha: 0.3) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _scannedReturnIds.contains(p.id) ? AppColors.delivered : AppColors.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _scannedReturnIds.contains(p.id) ? Icons.check_circle : Icons.inventory_2_outlined,
                            color: _scannedReturnIds.contains(p.id) ? AppColors.delivered : AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.id,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.plum),
                                ),
                                Text(
                                  '${p.receiverName} · ${p.failureReason ?? "Pending delivery"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _scannedReturnIds.contains(p.id) ? Icons.check : Icons.barcode_reader,
                              size: 18,
                              color: _scannedReturnIds.contains(p.id) ? AppColors.delivered : AppColors.plum,
                            ),
                            onPressed: () => _scanReturnBarcode(p.id),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),

          // Bottom Complete Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _completeIntake,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  foregroundColor: AppColors.cream,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Confirm Hub Intake & Close Run',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

