import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/delivery_request.dart';
import '../services/mock_backend.dart';
import '../theme/app_colors.dart';

class ParcelScannerSheet extends StatefulWidget {
  const ParcelScannerSheet({
    super.key,
    this.targetParcel,
    this.availableParcels,
    this.onParcelScanned,
    this.onDone,
  });

  final DeliveryRequest? targetParcel;
  final List<DeliveryRequest>? availableParcels;
  final ValueChanged<DeliveryRequest>? onParcelScanned;
  final VoidCallback? onDone;

  @override
  State<ParcelScannerSheet> createState() => _ParcelScannerSheetState();
}

class _ParcelScannerSheetState extends State<ParcelScannerSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final MobileScannerController _scannerController;

  late AnimationController _animController;
  late Animation<double> _scanLineAnimation;

  DeliveryRequest? _lastScannedParcel;
  String? _successMessage;
  final Set<String> _scannedInSession = <String>{};
  bool _isProcessingCode = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _barcodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessingCode) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _isProcessingCode = true;
        _handleBarcodeScanned(code).whenComplete(() {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              _isProcessingCode = false;
            }
          });
        });
        break;
      }
    }
  }

  List<DeliveryRequest> get _manifest {
    return widget.availableParcels ?? MockBackend().parcelsNotifier.value;
  }

  Future<void> _handleBarcodeScanned(String rawBarcode) async {
    final code = rawBarcode.trim();
    if (code.isEmpty) return;

    _barcodeController.clear();

    // 1. Search in assigned parcels
    final lowerCode = code.toLowerCase();
    final match = _manifest.where(
      (p) =>
          p.id.toLowerCase() == lowerCode ||
          p.barcode?.toLowerCase() == lowerCode ||
          p.trackingNumber?.toLowerCase() == lowerCode,
    );

    if (match.isEmpty) {
      _showNotAssignedDialog(code);
      return;
    }

    final parcel = match.first;

    // If targeted at a specific parcel, ensure it matches
    if (widget.targetParcel != null && parcel.id != widget.targetParcel!.id) {
      _showMismatchDialog(code, parcel);
      return;
    }

    // 2. Check if already picked up or beyond
    if (parcel.stage != DeliveryStage.accepted && !_scannedInSession.contains(parcel.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parcel ${parcel.id} is already in status: ${parcel.stage.name.toUpperCase()}.'),
          backgroundColor: AppColors.plum,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _lastScannedParcel = parcel;
        _successMessage = 'Parcel ${parcel.id} was already picked up.';
      });
      return;
    }

    // 3. Mark Picked Up
    await MockBackend().updateParcelStatus(parcel.id, DeliveryStage.pickedUp);
    final updatedParcel = parcel.copyWith(stage: DeliveryStage.pickedUp);

    setState(() {
      _scannedInSession.add(parcel.id);
      _lastScannedParcel = updatedParcel;
      _successMessage = '✓ Scanned & Status Updated to Picked Up!';
    });

    widget.onParcelScanned?.call(updatedParcel);

    // If targeted, briefly show success then auto-pop after short delay
    if (widget.targetParcel != null) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _showNotAssignedDialog(String code) {
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
          'Parcel Not Assigned!',
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
              'This barcode is not assigned to your route manifest for Today\'s Run. Do not load or pick up this parcel.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink, height: 1.4),
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
              child: Text('Dismiss', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showMismatchDialog(String code, DeliveryRequest actual) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.orange, width: 2),
        ),
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.pendingSoft,
          child: Icon(Icons.qr_code_2, color: AppColors.orange, size: 36),
        ),
        title: Text(
          'Wrong Parcel Scanned',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.plum,
          ),
        ),
        content: Text(
          'You are viewing ${widget.targetParcel!.id}, but scanned ${actual.id} ($code). Please scan the barcode matching ${widget.targetParcel!.barcode ?? widget.targetParcel!.id}.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink, height: 1.4),
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
              child: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedParcels = _manifest.where((p) => p.stage == DeliveryStage.accepted).toList();
    final pickedUpParcels = _manifest.where((p) => p.stage == DeliveryStage.pickedUp).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF13151B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header: Title + Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: AppColors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARCEL BARCODE SCANNER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          widget.targetParcel != null
                              ? 'Scan barcode for ${widget.targetParcel!.id}'
                              : 'Scan parcel to update status to Picked Up',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      widget.onDone?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Target parcel focus card (if specified)
                    if (widget.targetParcel != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.plum,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pin_drop, color: AppColors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TARGET STOP: ${widget.targetParcel!.receiverName}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Required Barcode: ${widget.targetParcel!.barcode ?? widget.targetParcel!.id}',
                                    style: GoogleFonts.inter(
                                      color: AppColors.blush2,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Camera Viewfinder Box with Animated Laser Scan Line
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white12, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Real Live Camera Viewfinder via mobile_scanner
                              MobileScanner(
                                controller: _scannerController,
                                fit: BoxFit.cover,
                                onDetect: _onBarcodeDetected,
                                errorBuilder: (context, error) {
                                  return Container(
                                    color: const Color(0xFF0F1117),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 40),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Camera unavailable (${error.errorCode.name})',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Check camera permission or enter barcode below',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: AppColors.orange,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                placeholderBuilder: (context) {
                                  return Container(
                                    color: const Color(0xFF0F1117),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2),
                                    ),
                                  );
                                },
                              ),

                              // Viewfinder Target Corners
                              Center(
                                child: SizedBox(
                                  width: 220,
                                  height: 120,
                                  child: Stack(
                                    children: [
                                      // Top Left Corner
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(color: AppColors.orange, width: 3),
                                              left: BorderSide(color: AppColors.orange, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Top Right Corner
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(color: AppColors.orange, width: 3),
                                              right: BorderSide(color: AppColors.orange, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Bottom Left Corner
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: AppColors.orange, width: 3),
                                              left: BorderSide(color: AppColors.orange, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Bottom Right Corner
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: AppColors.orange, width: 3),
                                              right: BorderSide(color: AppColors.orange, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Moving Animated Laser Line
                                      AnimatedBuilder(
                                        animation: _scanLineAnimation,
                                        builder: (context, child) {
                                          return Positioned(
                                            top: 120 * _scanLineAnimation.value,
                                            left: 6,
                                            right: 6,
                                            child: Container(
                                              height: 2,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.orange.withValues(alpha: 0.1),
                                                    AppColors.orange,
                                                    AppColors.rose,
                                                    AppColors.orange,
                                                    AppColors.orange.withValues(alpha: 0.1),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.orange.withValues(alpha: 0.8),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Viewfinder Bottom Hint
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'ALIGN BARCODE IN FRAME',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white70,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Viewfinder Overlay Controls (Torch & Camera Switch)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Row(
                                  children: [
                                    ValueListenableBuilder<MobileScannerState>(
                                      valueListenable: _scannerController,
                                      builder: (context, state, child) {
                                        final isTorchOn = state.torchState == TorchState.on;
                                        return IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: isTorchOn
                                                ? AppColors.gold
                                                : Colors.black.withValues(alpha: 0.5),
                                            iconSize: 18,
                                          ),
                                          icon: Icon(
                                            isTorchOn ? Icons.flash_on : Icons.flash_off,
                                            color: isTorchOn ? Colors.black : Colors.white,
                                          ),
                                          onPressed: () => _scannerController.toggleTorch(),
                                          tooltip: 'Toggle Flashlight',
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                                        iconSize: 18,
                                      ),
                                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 18),
                                      onPressed: () => _scannerController.switchCamera(),
                                      tooltip: 'Switch Camera',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Manual Barcode Input Row (Works seamlessly with Laser Scanner Guns & Keyboards)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: TextField(
                              controller: _barcodeController,
                              focusNode: _focusNode,
                              onSubmitted: _handleBarcodeScanned,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter barcode or scan with gun...',
                                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                                prefixIcon: const Icon(Icons.qr_code, color: AppColors.orange, size: 20),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: () => _handleBarcodeScanned(_barcodeController.text),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.plum,
                              foregroundColor: AppColors.cream,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Text(
                              'Scan',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Scan Feedback Banner (shows immediately after successful scan)
                    if (_successMessage != null && _lastScannedParcel != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.deliveredSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.delivered, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.delivered, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _successMessage!,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: AppColors.delivered,
                                    ),
                                  ),
                                  Text(
                                    '${_lastScannedParcel!.id} · ${_lastScannedParcel!.receiverName} (${_lastScannedParcel!.deliveryArea})',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Status guidance info when no parcel has been scanned in this session
                    if (_lastScannedParcel == null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner, color: AppColors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Point camera at parcel label barcode or enter code above. Scanned parcels will automatically update to Picked Up.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],

                    // Primary Bottom Stage Transition Button
                    if (pickedUpParcels.isNotEmpty) ...[
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final toStart = pickedUpParcels.map((p) => p.id).toList();
                            await MockBackend().startDeliveryRun(toStart);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${toStart.length} parcel(s) marked Out for Delivery!'),
                                  backgroundColor: AppColors.plum,
                                ),
                              );
                              widget.onDone?.call();
                              Navigator.of(context).pop();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.delivered,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.navigation_outlined, size: 18),
                          label: Text(
                            'Start Out for Delivery (${pickedUpParcels.length} Picked Up)',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onDone?.call();
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Close Scanner',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

