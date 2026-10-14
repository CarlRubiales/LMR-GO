import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/delivery_request.dart';
import '../services/mock_backend.dart';
import '../theme/app_colors.dart';

class PodSheet extends StatefulWidget {
  const PodSheet({
    super.key,
    required this.parcel,
    required this.onDelivered,
  });

  final DeliveryRequest parcel;
  final VoidCallback onDelivered;

  @override
  State<PodSheet> createState() => _PodSheetState();
}

class _PodSheetState extends State<PodSheet> {
  String? _photoPath;
  bool _useSignature = true; // true: signature, false: OTP
  final List<List<Offset>> _signaturePoints = <List<Offset>>[];
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  bool _codConfirmed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.parcel.isCod) {
      _cashReceivedController.text = widget.parcel.codAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      // Fallback for emulator or permissions: mock image path
      setState(() => _photoPath = 'simulated_pod_camera_${widget.parcel.id}.jpg');
    }
  }

  double get _changeDue {
    if (!widget.parcel.isCod) return 0.0;
    final received = double.tryParse(_cashReceivedController.text) ?? 0.0;
    final change = received - widget.parcel.codAmount;
    return change > 0 ? change : 0.0;
  }

  bool get _canSubmit {
    // Requires photo or signature or OTP
    final hasProof = _photoPath != null ||
        _signaturePoints.isNotEmpty ||
        _otpController.text.trim().length >= 4;

    if (!hasProof) return false;

    // If COD, requires confirmation
    if (widget.parcel.isCod && widget.parcel.codAmount > 0 && !_codConfirmed) {
      return false;
    }

    return true;
  }

  Future<void> _submitPod() async {
    if (!_canSubmit || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final sigRepresentation = _signaturePoints.isNotEmpty ? 'sig_captured_points_${_signaturePoints.length}' : null;
    final otpValue = !_useSignature ? _otpController.text.trim() : null;

    await MockBackend().updateParcelStatus(
      widget.parcel.id,
      DeliveryStage.delivered,
      podPhotoPath: _photoPath,
      podSignature: sigRepresentation,
      podOtp: otpValue,
      codAmountCollected: widget.parcel.isCod ? widget.parcel.codAmount : 0.0,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onDelivered();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parcel ${widget.parcel.id} marked DELIVERED!'),
          backgroundColor: AppColors.delivered,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      'Proof of Delivery',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.parcel.id} · ${widget.parcel.receiverName}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
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
          const Divider(height: 20, color: AppColors.line),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // Step 1: Photo Capture Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_camera_outlined, color: AppColors.plum, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '1. DELIVERY PHOTO',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.plum,
                            ),
                          ),
                          const Spacer(),
                          if (_photoPath != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.deliveredSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PHOTO ATTACHED',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.delivered,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_photoPath == null)
                        InkWell(
                          onTap: _takePhoto,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.blush1,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line, style: BorderStyle.solid),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.camera_alt, color: AppColors.plum, size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Take Doorstep / Receiver Photo',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.plum,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Stack(
                          children: [
                            Container(
                              height: 130,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF222831),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _photoPath!.startsWith('simulated_')
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified, color: AppColors.delivered, size: 36),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Doorstep Photo Captured\n(Timestamped & Watermarked)',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Image.file(File(_photoPath!), fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: _takePhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.refresh, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Step 2: Receiver Signature or OTP Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: AppColors.plum, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '2. RECEIVER CONFIRMATION',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.plum,
                            ),
                          ),
                          const Spacer(),
                          // Toggle between Signature and OTP
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.blush1,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _useSignature = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _useSignature ? AppColors.plum : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Signature',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _useSignature ? Colors.white : AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _useSignature = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: !_useSignature ? AppColors.plum : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'OTP',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: !_useSignature ? Colors.white : AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_useSignature) ...[
                        // Signature Canvas
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Stack(
                            children: [
                              GestureDetector(
                                onPanStart: (details) {
                                  setState(() {
                                    _signaturePoints.add([details.localPosition]);
                                  });
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    if (_signaturePoints.isNotEmpty) {
                                      _signaturePoints.last.add(details.localPosition);
                                    }
                                  });
                                },
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _SignaturePainter(points: _signaturePoints),
                                ),
                              ),
                              if (_signaturePoints.isEmpty)
                                Center(
                                  child: Text(
                                    'Receiver signs here with finger',
                                    style: GoogleFonts.inter(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _signaturePoints.clear()),
                                  icon: const Icon(Icons.clear, size: 14, color: AppColors.muted),
                                  label: Text(
                                    'Clear',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // OTP Input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Enter 4-6 digit SMS OTP',
                                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppColors.blush1,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => setState(() => _otpController.text = '5821'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.blush2,
                                foregroundColor: AppColors.plum,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Auto-Fill'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Step 3: COD Cash Collection Confirmation Card
                if (widget.parcel.isCod && widget.parcel.codAmount > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.blush1,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: AppColors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '3. CASH ON DELIVERY (COD)',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.orange,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.parcel.formattedCod,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cash Received',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 42,
                                    child: TextField(
                                      controller: _cashReceivedController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        prefixText: '₱ ',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppColors.line),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Change to Return',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.line),
                                    ),
                                    child: Text(
                                      '₱${_changeDue.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.plum,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: _codConfirmed,
                          onChanged: (v) => setState(() => _codConfirmed = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.delivered,
                          title: Text(
                            'I confirm collecting ₱${widget.parcel.codAmount.toStringAsFixed(2)} cash',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.deliveredSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.delivered, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'PREPAID ORDER · No cash collection needed',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.delivered,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              child: FilledButton.icon(
                onPressed: _canSubmit && !_isSubmitting ? _submitPod : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.delivered,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.line,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check, size: 22),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Confirm & Complete Delivery',
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

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.points});

  final List<List<Offset>> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.plum
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (final stroke in points) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

