import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/delivery_request.dart';
import '../services/api_service.dart';
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
  final Map<String, String> _manualScanNotes = <String, String>{};
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  bool _isCashCounted = false;
  bool _isSubmitting = false;
  String? _inlineError;

  List<DeliveryRequest> get _deliveredParcels {
    return widget.allParcels.where((p) => p.isDelivered).toList();
  }

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

  int get _codParcelsCount {
    return widget.allParcels.where((p) => p.isCod && p.codAmount > 0).length;
  }

  int get _deliveredCodParcelsCount {
    return _deliveredParcels.where((p) => p.isCod && p.codAmount > 0).length;
  }

  bool get _isCodRemittedToday =>
      MockBackend().isCodRemittedForDate(MockBackend().selectedDate);

  /// Exact money calculation using integer centavos to avoid float/double rounding errors
  int get _totalCodCentavos {
    if (_isCodRemittedToday) {
      final unremittedDelivered = _deliveredParcels.where((p) => p.isCod && !p.isCodRemitted).toList();
      final remittedAmount = MockBackend().getRemittedCodAmount(MockBackend().selectedDate);
      final unremittedTotal = unremittedDelivered.fold(0.0, (s, p) => s + p.codAmount);
      if (unremittedDelivered.isEmpty || (remittedAmount > 0 && remittedAmount >= unremittedTotal)) {
        return 0;
      }
    }
    return _deliveredParcels
        .where((p) => p.isCod && p.codAmount > 0 && !p.isCodRemitted)
        .fold(0, (sum, p) {
      final centavos = (p.codAmount * 100).round();
      return sum + centavos;
    });
  }

  String _formatPesoFromCentavos(int centavos) {
    final double pesos = centavos / 100.0;
    final parts = pesos.toStringAsFixed(2).split('.');
    final integerDigits = parts[0];
    final decimalDigits = parts[1];

    final regExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = integerDigits.replaceAllMapped(regExp, (Match m) => '${m[1]},');
    return '₱$formattedInt.$decimalDigits';
  }

  bool get _isRunClosable {
    final undelivered = _undeliveredParcels;
    final allScanned = undelivered.isEmpty ||
        undelivered.every((p) => _scannedReturnIds.contains(p.id));

    if (!allScanned) return false;
    if (_totalCodCentavos > 0 && !_isCashCounted) return false;
    return true;
  }

  String get _missingRequirementsMessage {
    final undelivered = _undeliveredParcels;
    final missingScanCount = undelivered.where((p) => !_scannedReturnIds.contains(p.id)).length;
    final needsCashConfirm = _totalCodCentavos > 0 && !_isCashCounted;

    if (missingScanCount > 0 && needsCashConfirm) {
      return 'Still needed: scan $missingScanCount ${missingScanCount == 1 ? "parcel" : "parcels"} and confirm the cash';
    } else if (missingScanCount > 0) {
      return 'Still needed: scan $missingScanCount ${missingScanCount == 1 ? "parcel" : "parcels"} to complete intake';
    } else if (needsCashConfirm) {
      return 'Still needed: tick "I counted the cash" before handover';
    }
    return 'All checks passed. Ready to close run.';
  }

  @override
  void initState() {
    super.initState();
    // Pre-populate any parcels already marked as returnedToHub
    for (final p in _undeliveredParcels) {
      if (p.stage == DeliveryStage.returnedToHub) {
        _scannedReturnIds.add(p.id);
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _triggerErrorFeedback(String message) {
    HapticFeedback.vibrate();
    setState(() => _inlineError = message);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppColors.failed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerSuccessFeedback(DeliveryRequest parcel) {
    HapticFeedback.lightImpact();
    setState(() {
      _scannedReturnIds.add(parcel.id);
      _inlineError = null;
    });
    _barcodeController.clear();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scanned ${parcel.id} (${parcel.receiverName})',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppColors.delivered,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  void _processBarcode(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;

    final undelivered = _undeliveredParcels;
    final cleanCode = code.toLowerCase().replaceAll('#', '');

    final matches = undelivered.where((p) {
      final pid = p.id.toLowerCase().replaceAll('#', '');
      final pbar = (p.barcode ?? '').toLowerCase().replaceAll('#', '');
      final ptrk = (p.trackingNumber ?? '').toLowerCase().replaceAll('#', '');
      return pid == cleanCode || pbar == cleanCode || ptrk == cleanCode;
    }).toList();

    if (matches.isEmpty) {
      final isDeliveredParcel = widget.allParcels.any((p) {
        final pid = p.id.toLowerCase().replaceAll('#', '');
        final pbar = (p.barcode ?? '').toLowerCase().replaceAll('#', '');
        return (pid == cleanCode || pbar == cleanCode) && p.isDelivered;
      });

      if (isDeliveredParcel) {
        _triggerErrorFeedback('Parcel $code was successfully delivered. Not undelivered.');
      } else {
        _triggerErrorFeedback('Unknown barcode "$code" is not in today\'s undelivered list.');
      }
      return;
    }

    final parcel = matches.first;
    if (_scannedReturnIds.contains(parcel.id)) {
      _triggerErrorFeedback('Parcel ${parcel.id} was already scanned.');
      return;
    }

    _triggerSuccessFeedback(parcel);
  }

  Future<void> _openCameraScanner() async {
    HapticFeedback.selectionClick();
    final scannedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CameraBarcodeScannerDialog(
        undeliveredParcels: _undeliveredParcels,
        scannedReturnIds: _scannedReturnIds,
      ),
    );

    if (scannedCode != null && scannedCode.trim().isNotEmpty) {
      _processBarcode(scannedCode);
    }
  }

  Future<void> _confirmMarkAllIn() async {
    final remaining = _undeliveredParcels.where((p) => !_scannedReturnIds.contains(p.id)).toList();
    if (remaining.isEmpty) return;

    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark all in?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.plum,
          ),
        ),
        content: Text(
          'Are you sure you want to mark all ${remaining.length} remaining undelivered parcels as scanned in? Please confirm you physically have these parcels with you.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.plum,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Confirm All',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.cream),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        for (final p in remaining) {
          _scannedReturnIds.add(p.id);
        }
        _inlineError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked all ${remaining.length} undelivered parcels as scanned in.'),
          backgroundColor: AppColors.delivered,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openManualIntakeDialog(DeliveryRequest parcel) async {
    final noteController = TextEditingController(text: _manualScanNotes[parcel.id] ?? '');
    final formKey = GlobalKey<FormState>();

    HapticFeedback.selectionClick();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Manual Intake',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.plum,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parcel: ${parcel.id}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.plum),
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${parcel.receiverName}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Text(
                'A note is required when manually scanning a damaged or unreadable barcode.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink, height: 1.3),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                maxLines: 3,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'e.g., Barcode label scratched; verified recipient & address on waybill.',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Please enter a note (at least 5 characters).';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.plum,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(noteController.text.trim());
              }
            },
            child: Text(
              'Verify & Mark In',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.cream),
            ),
          ),
        ],
      ),
    );

    if (note != null && note.isNotEmpty && mounted) {
      _manualScanNotes[parcel.id] = note;
      _triggerSuccessFeedback(parcel);
    }
  }

  Future<void> _submitCloseRun() async {
    if (_isSubmitting) return; // Prevent double-tap / ensure idempotent execution
    setState(() => _isSubmitting = true);

    try {
      final undelivered = _undeliveredParcels;

      // Update undelivered parcels to returnedToHub status with reason & any manual note
      for (final p in undelivered) {
        final manualNote = _manualScanNotes[p.id];
        final failureReason = p.failureReason ?? 'Returned to Hub Sorting';
        final combinedNotes = [
          p.failureNotes,
          if (manualNote != null) 'Manual intake: $manualNote',
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' | ');

        await MockBackend().updateParcelStatus(
          p.id,
          DeliveryStage.returnedToHub,
          failureReason: failureReason,
          failureNotes: combinedNotes.isNotEmpty ? combinedNotes : null,
        );
      }

      if (!mounted) return;

      final now = DateTime.now();
      final riderName = ApiService.instance.currentUser?['name'] ?? 'Courier Partner';
      final formattedTotal = _formatPesoFromCentavos(_totalCodCentavos);
      final codAmountToRemit = _totalCodCentavos / 100.0;

      // Remit COD cash so today's balance turns back to 0 & status becomes awaiting_cashier
      await MockBackend().remitCodCash(
        date: MockBackend().selectedDate,
        amount: codAmountToRemit,
        hubCashierNote: 'EOD Intake & Remit closed by $riderName',
        parcelIds: _deliveredParcels.where((p) => p.isCod).map((p) => p.id).toList(),
      );

      // Dismiss the return sheet
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onComplete();

      // Show receipt confirmation sheet
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ReceiptBottomSheet(
          timestamp: now,
          riderName: riderName.toString(),
          deliveredCount: _deliveredParcels.length,
          returnedCount: undelivered.length,
          codTotalFormatted: formattedTotal,
          deliveredCodCount: _deliveredCodParcelsCount,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _triggerErrorFeedback('Failed to close run: $e. Please check connection and retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final undelivered = _undeliveredParcels;
    final isAllDelivered = undelivered.isEmpty;
    final totalCentavos = _totalCodCentavos;
    final codFormatted = _formatPesoFromCentavos(totalCentavos);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 1. Header (fixed 44px close button, non-overflowing wrapping subtitle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
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
                        const SizedBox(height: 3),
                        Text(
                          'Hand over undelivered parcels & COD cash to hub cashier',
                          maxLines: 2,
                          softWrap: true,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Close End of Day Return and Remit',
                    button: true,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, color: AppColors.line),

            // Middle scrollable section
            Expanded(
              child: isAllDelivered
                  ? _buildAllDeliveredBody(codFormatted)
                  : _buildUndeliveredBody(undelivered, totalCentavos, codFormatted),
            ),

            // 6. Sticky Footer
            _buildStickyFooter(isAllDelivered),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final deliveredCount = _deliveredParcels.length;
    final undeliveredCount = _undeliveredParcels.length;
    final codCount = _codParcelsCount;

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'DELIVERED',
            count: deliveredCount.toString(),
            color: AppColors.delivered,
            bgColor: AppColors.deliveredSoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'UNDELIVERED',
            count: undeliveredCount.toString(),
            color: undeliveredCount > 0 ? AppColors.failed : AppColors.muted,
            bgColor: undeliveredCount > 0 ? AppColors.failedSoft : Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'COD PARCELS',
            count: codCount.toString(),
            color: AppColors.orange,
            bgColor: AppColors.blush1,
          ),
        ),
      ],
    );
  }

  Widget _buildCodCard(int totalCentavos, String codFormatted) {
    if (totalCentavos <= 0) {
      final isRemitted = _isCodRemittedToday;
      final remittedAmount = MockBackend().getRemittedCodAmount(MockBackend().selectedDate);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isRemitted ? AppColors.deliveredSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isRemitted ? AppColors.delivered.withValues(alpha: 0.35) : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              isRemitted ? Icons.check_circle_outline : Icons.account_balance_wallet_outlined,
              color: isRemitted ? AppColors.delivered : AppColors.muted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRemitted ? 'COD CASH REMITTED TODAY' : 'COD CASH TO REMIT',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isRemitted ? AppColors.delivered : AppColors.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRemitted
                        ? (remittedAmount > 0
                            ? 'All COD cash (₱${remittedAmount.toStringAsFixed(2)}) remitted to hub.'
                            : 'All COD cash remitted to hub cashier.')
                        : 'No cash to hand over today.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isRemitted ? AppColors.delivered : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₱0.00',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isRemitted ? AppColors.delivered : AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blush1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'COD CASH TO REMIT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              codFormatted,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.plum,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Collected from $_deliveredCodParcelsCount delivered ${_deliveredCodParcelsCount == 1 ? "parcel" : "parcels"}. Present exact cash to Hub Cashier.',
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted, height: 1.3),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'I counted the cash checkbox',
            checked: _isCashCounted,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isCashCounted = !_isCashCounted);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isCashCounted,
                        activeColor: AppColors.plum,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _isCashCounted = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I counted the cash and it matches $codFormatted',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDeliveredBody(String codFormatted) {
    final deliveredCount = _deliveredParcels.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        _buildSummaryStrip(),
        const SizedBox(height: 14),
        _buildCodCard(_totalCodCentavos, codFormatted),
        const SizedBox(height: 24),

        // 7. All-delivered state (Green check illustration, clean typography, NO emojis)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.deliveredSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.delivered,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All parcels delivered',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.plum,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$deliveredCount delivered, 0 to return, $codFormatted to remit',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All customer stops for today are complete. Hand over any COD remittance above to conclude your run.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUndeliveredBody(
    List<DeliveryRequest> undelivered,
    int totalCentavos,
    String codFormatted,
  ) {
    final scannedCount = _scannedReturnIds.length;
    final totalCount = undelivered.length;
    final progress = totalCount > 0 ? (scannedCount / totalCount).clamp(0.0, 1.0) : 1.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        _buildSummaryStrip(),
        const SizedBox(height: 14),
        _buildCodCard(totalCentavos, codFormatted),
        const SizedBox(height: 16),

        // 4. Barcode Scan Section
        Text(
          'SCAN UNDELIVERED PARCELS INTO HUB',
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
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode,
                  onSubmitted: _processBarcode,
                  style: GoogleFonts.inter(fontSize: 13),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Enter barcode or track ID...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.plum, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'Open camera barcode scanner',
              button: true,
              child: SizedBox(
                width: 44,
                height: 44,
                child: OutlinedButton(
                  onPressed: _openCameraScanner,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: AppColors.plum, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => _processBarcode(_barcodeController.text),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  foregroundColor: AppColors.cream,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Intake',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),

        if (_inlineError != null) ...[
          const SizedBox(height: 6),
          Text(
            _inlineError!,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.failed),
          ),
        ],

        const SizedBox(height: 16),

        // 5. Undelivered Header + Progress + "Mark all in"
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Undelivered · $scannedCount of $totalCount scanned',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.plum,
              ),
            ),
            if (scannedCount < totalCount)
              Semantics(
                label: 'Mark all undelivered parcels as scanned in',
                button: true,
                child: TextButton(
                  onPressed: _confirmMarkAllIn,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Mark all in',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation<Color>(
              scannedCount == totalCount ? AppColors.delivered : AppColors.orange,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // List of Undelivered Parcels
        for (final p in undelivered) ...[
          _buildUndeliveredRow(p),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildUndeliveredRow(DeliveryRequest parcel) {
    final isScanned = _scannedReturnIds.contains(parcel.id);
    final reason = parcel.failureReason ?? 'Pending delivery';
    final hasManualNote = _manualScanNotes.containsKey(parcel.id);

    return Semantics(
      label: 'Parcel ${parcel.id}, for ${parcel.receiverName}. Status: ${isScanned ? "Scanned" : "To scan"}. Reason: $reason.',
      button: true,
      child: Material(
        color: isScanned ? AppColors.deliveredSoft.withValues(alpha: 0.45) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!isScanned) {
              _openManualIntakeDialog(parcel);
            }
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isScanned ? AppColors.delivered : AppColors.line,
                width: isScanned ? 1.2 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Tick or Empty Circle
                Icon(
                  isScanned ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isScanned ? AppColors.delivered : AppColors.muted,
                  size: 22,
                ),
                const SizedBox(width: 10),

                // Parcel ID, Customer Name & Failure Reason
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              parcel.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.plum,
                              ),
                            ),
                          ),
                          if (hasManualNote) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.blush1,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Manual',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.plum,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${parcel.receiverName} · $reason',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Scanned / To scan Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isScanned ? AppColors.deliveredSoft : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isScanned ? AppColors.delivered.withValues(alpha: 0.4) : AppColors.line,
                    ),
                  ),
                  child: Text(
                    isScanned ? 'Scanned' : 'To scan',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isScanned ? AppColors.delivered : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyFooter(bool isAllDelivered) {
    final canClose = _isRunClosable && !_isSubmitting;
    final hint = _missingRequirementsMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Missing requirements explanation line
          if (!isAllDelivered && !canClose) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: canClose ? _submitCloseRun : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.plum,
                disabledBackgroundColor: AppColors.plum.withValues(alpha: 0.35),
                foregroundColor: AppColors.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isAllDelivered
                          ? 'Close Run'
                          : 'Confirm Hub Intake & Close Run',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final String count;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.plum,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBarcodeScannerDialog extends StatefulWidget {
  const _CameraBarcodeScannerDialog({
    required this.undeliveredParcels,
    required this.scannedReturnIds,
  });

  final List<DeliveryRequest> undeliveredParcels;
  final Set<String> scannedReturnIds;

  @override
  State<_CameraBarcodeScannerDialog> createState() => _CameraBarcodeScannerDialogState();
}

class _CameraBarcodeScannerDialogState extends State<_CameraBarcodeScannerDialog> {
  late final MobileScannerController _controller;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _hasDetected = true;
        Navigator.of(context).pop(code);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Scan Parcel Barcode',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.flash_on, color: Colors.white),
                  onPressed: () => _controller.toggleTorch(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Container(
                  width: 250,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.orange, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Align parcel barcode within the frame to scan into hub intake.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptBottomSheet extends StatelessWidget {
  const _ReceiptBottomSheet({
    required this.timestamp,
    required this.riderName,
    required this.deliveredCount,
    required this.returnedCount,
    required this.codTotalFormatted,
    required this.deliveredCodCount,
  });

  final DateTime timestamp;
  final String riderName;
  final int deliveredCount;
  final int returnedCount;
  final String codTotalFormatted;
  final int deliveredCodCount;

  @override
  Widget build(BuildContext context) {
    final dateFormatted =
        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.deliveredSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.delivered, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intake & Remittance Receipt',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      Text(
                        'End of Day run closed successfully',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.line),
            const SizedBox(height: 12),
            _receiptRow('Courier', riderName),
            _receiptRow('Recorded At', dateFormatted),
            _receiptRow('Delivered Parcels', '$deliveredCount parcels'),
            _receiptRow('Returned to Hub', '$returnedCount parcels'),
            _receiptRow('COD Cash Handed Over', codTotalFormatted, isHighlight: true),
            const SizedBox(height: 12),
            const Divider(color: AppColors.line),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.cream),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isHighlight ? 14 : 12.5,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight ? AppColors.plum : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
