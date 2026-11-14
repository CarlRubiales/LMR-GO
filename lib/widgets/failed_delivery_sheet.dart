import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/delivery_request.dart';
import '../services/api_service.dart';
import '../services/mock_backend.dart';
import '../theme/app_colors.dart';

class FailedDeliverySheet extends StatefulWidget {
  const FailedDeliverySheet({
    super.key,
    required this.parcel,
    required this.onFailedRecorded,
    this.isPostDelivery = false,
  });

  final DeliveryRequest parcel;
  final VoidCallback onFailedRecorded;
  final bool isPostDelivery;

  @override
  State<FailedDeliverySheet> createState() => _FailedDeliverySheetState();
}

class _FailedDeliverySheetState extends State<FailedDeliverySheet> {
  static const List<String> _reasons = [
    'Damaged / Defective Item',
    'Wrong Item / Incomplete Order',
    'Customer Refused / Cancelled Order',
    'Item Does Not Match Description',
    'Customer Unreachable / Not Home',
    'Wrong / Incomplete Delivery Address',
    'Other Return / Refund Reason',
  ];

  String? _selectedReason;
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _photoPath;
  String? _videoPath;
  bool _isReschedule = false;
  String _selectedWindow = 'Tomorrow · Morning (9AM - 12PM)';
  bool _submitting = false;

  static const List<String> _rescheduleWindows = [
    'Tomorrow · Morning (9AM - 12PM)',
    'Tomorrow · Afternoon (1PM - 5PM)',
    'Next Business Day · Standard Window',
  ];

  bool get _isReturnClaim =>
      widget.isPostDelivery ||
      widget.parcel.isReturnRefund ||
      widget.parcel.isDelivered ||
      widget.parcel.isReturnedToHub ||
      widget.parcel.returnReason != null;

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.parcel.returnReason ?? widget.parcel.failureReason;
    if (_notesController.text.isEmpty) {
      final initialNotes = widget.parcel.returnDetails ?? widget.parcel.failureNotes;
      if (initialNotes != null && initialNotes.isNotEmpty) {
        _notesController.text = initialNotes;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 78,
      );
      if (image != null && mounted) {
        setState(() {
          _photoPath = image.path;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to access camera/gallery for photo.'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null && mounted) {
        setState(() {
          _videoPath = video.path;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to access camera/gallery for video.'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  /// Action when rider confirms return parcel is in his hands (collected from buyer)
  Future<void> _submitItemInHand() async {
    setState(() => _submitting = true);

    try {
      final reason = widget.parcel.effectiveReturnReason;
      final notes = widget.parcel.effectiveReturnDetails;

      await MockBackend().updateParcelStatus(
        widget.parcel.id,
        DeliveryStage.returningToHub,
        failureReason: reason,
        failureNotes: notes,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onFailedRecorded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item in hand confirmed for ${widget.parcel.id}. Hand in to hub when ready.'),
            backgroundColor: AppColors.plum,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  /// Action when rider marks parcel as Returned to Hub
  Future<void> _submitReturnedToHub() async {
    setState(() => _submitting = true);

    try {
      final reason = widget.parcel.effectiveReturnReason;
      final notes = widget.parcel.effectiveReturnDetails;

      await MockBackend().updateParcelStatus(
        widget.parcel.id,
        DeliveryStage.returnedToHub,
        failureReason: reason,
        failureNotes: notes,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onFailedRecorded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcel ${widget.parcel.id} marked as Returned to Hub'),
            backgroundColor: AppColors.plum,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  /// Action for regular pre-delivery failed delivery
  Future<void> _submitAction() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for Return / Refund.'),
          backgroundColor: AppColors.failed,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final stage = _isReschedule ? DeliveryStage.rescheduled : DeliveryStage.failed;
    final notesText = _notesController.text.trim();
    final fullNotes = _isReschedule
        ? 'Rescheduled for $_selectedWindow. $notesText'.trim()
        : notesText;

    await MockBackend().updateParcelStatus(
      widget.parcel.id,
      stage,
      failureReason: _selectedReason,
      failureNotes: fullNotes,
      podPhotoPath: _photoPath,
      podVideoPath: _videoPath,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onFailedRecorded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isReschedule
                ? 'Parcel ${widget.parcel.id} rescheduled for $_selectedWindow'
                : 'Parcel ${widget.parcel.id} submitted for Return/Refund ($_selectedReason)',
          ),
          backgroundColor: _isReschedule ? AppColors.orange : AppColors.failed,
        ),
      );
    }
  }

  String _resolveMediaUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('data:')) {
      return trimmed;
    }
    // Resolve relative paths against backend server origin
    final base = ApiService.instance.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    if (trimmed.startsWith('/')) {
      return '$base$trimmed';
    }
    return '$base/$trimmed';
  }

  Widget _buildMediaImage(String rawUrl, {BoxFit fit = BoxFit.cover, double? height, double? width}) {
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('data:image/')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          height: height,
          width: width,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    if (!kIsWeb && !trimmed.startsWith('http') && File(trimmed).existsSync()) {
      return Image.file(
        File(trimmed),
        fit: fit,
        height: height,
        width: width,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    final fullUrl = _resolveMediaUrl(trimmed);
    return Image.network(
      fullUrl,
      fit: fit,
      height: height,
      width: width,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          width: width,
          color: AppColors.blush1,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.plum),
          ),
        );
      },
      errorBuilder: (_, _, _) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.blush1,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, color: AppColors.muted, size: 28),
          SizedBox(height: 4),
          Text(
            'Evidence preview',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, String rawUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black87,
                  child: _buildMediaImage(rawUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fileBasename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : path;
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.failedSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_return_outlined,
                    color: AppColors.failed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isReturnClaim
                            ? 'Return / Refund Request'
                            : 'Report Failed Delivery',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.parcel.id} · ${widget.parcel.receiverName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 18, color: AppColors.line),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                if (_isReturnClaim) ...[
                  // Post-Delivery Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.parcel.stage == DeliveryStage.returningToHub
                          ? AppColors.blush1
                          : AppColors.failedSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.parcel.stage == DeliveryStage.returningToHub
                              ? Icons.front_hand_outlined
                              : Icons.assignment_return_outlined,
                          size: 18,
                          color: widget.parcel.stage == DeliveryStage.returningToHub
                              ? AppColors.plum
                              : AppColors.failed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.parcel.stage == DeliveryStage.returningToHub
                                    ? 'Parcel is in Your Hands · Heading to Hub'
                                    : 'Return Request · Collect from Buyer',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: widget.parcel.stage == DeliveryStage.returningToHub
                                      ? AppColors.plum
                                      : AppColors.failed,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.parcel.stage == DeliveryStage.returningToHub
                                    ? 'Item collected from buyer · Confirm when handed in to sorting hub'
                                    : 'Approved by Seller · Confirm item in hand once collected from buyer',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.ink),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Reason from E-Commerce Storefront
                  Text(
                    '1. BUYER RETURN / REFUND REASON',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.failedSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.report_problem_outlined, size: 14, color: AppColors.failed),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.parcel.effectiveReturnReason,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.failed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Buyer Explanation:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.blush1,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            widget.parcel.effectiveReturnDetails,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppColors.ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (widget.parcel.sellerNote != null &&
                            widget.parcel.sellerNote!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 14, color: AppColors.plum),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Seller Approval Note: ${widget.parcel.sellerNote}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.plum,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Buyer Return Items (if available)
                  if (widget.parcel.returnItems != null && widget.parcel.returnItems!.isNotEmpty) ...[
                    Text(
                      '2. RETURN ITEMS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.plum,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: widget.parcel.returnItems!.map((item) {
                          final name = item is Map ? (item['name'] ?? 'Item') : item.toString();
                          final qty = item is Map ? (item['quantity'] ?? 1) : 1;
                          final price = item is Map ? item['price'] : null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.plum),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$name (x$qty)',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                                  ),
                                ),
                                if (price != null)
                                  Text(
                                    '₱${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price}',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.plum),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Buyer Proof (Photo and Video Evidence)
                  Text(
                    '2. PROOF OF THE BUYER (EVIDENCE)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBuyerEvidenceCard(context),
                  const SizedBox(height: 20),
                ] else ...[
                  // Normal Failed Delivery Reporting View (pre-delivery failure)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.blush1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isReschedule = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isReschedule ? AppColors.failed : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'Return / Refund',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: !_isReschedule ? Colors.white : AppColors.plum,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isReschedule = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isReschedule ? AppColors.orange : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'Reschedule Delivery',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _isReschedule ? Colors.white : AppColors.plum,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    '1. SELECT RETURN / REFUND REASON *',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ..._reasons.map((reason) {
                    final isSelected = _selectedReason == reason;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.blush1 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.plum : AppColors.line,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: RadioListTile<String>(
                        value: reason,
                        groupValue: _selectedReason,
                        activeColor: AppColors.plum,
                        dense: true,
                        title: Text(
                          reason,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                        onChanged: (val) => setState(() => _selectedReason = val),
                      ),
                    );
                  }),

                  if (_isReschedule) ...[
                    const SizedBox(height: 10),
                    Text(
                      'SELECT NEW DELIVERY WINDOW',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.plum,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWindow,
                          isExpanded: true,
                          items: _rescheduleWindows.map((w) {
                            return DropdownMenuItem<String>(
                              value: w,
                              child: Text(w, style: GoogleFonts.inter(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWindow = val);
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  Text(
                    '2. ATTACH PICTURE (PHOTO EVIDENCE)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _photoPath != null ? AppColors.delivered : AppColors.line,
                        width: _photoPath != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_photoPath != null) ...[
                          if (!kIsWeb && File(_photoPath!).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(_photoPath!),
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.delivered, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Picture attached: ${_fileBasename(_photoPath!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.delivered,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(() => _photoPath = null),
                                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.failed),
                                label: Text(
                                  'Remove',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.failed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickPhoto(ImageSource.camera),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.plum,
                                    side: const BorderSide(color: AppColors.plum),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                  label: Text(
                                    'Take Picture',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickPhoto(ImageSource.gallery),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.plum,
                                    side: const BorderSide(color: AppColors.line),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: Text(
                                    'From Gallery',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    '3. ATTACH VIDEO (VIDEO EVIDENCE)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _videoPath != null ? AppColors.delivered : AppColors.line,
                        width: _videoPath != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_videoPath != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.deliveredSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.videocam, color: AppColors.delivered, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Video Clip Attached',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.delivered,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _fileBasename(_videoPath!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove video',
                                  onPressed: () => setState(() => _videoPath = null),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.failed, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickVideo(ImageSource.camera),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.plum,
                                    side: const BorderSide(color: AppColors.plum),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.videocam_outlined, size: 18),
                                  label: Text(
                                    'Record Video',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickVideo(ImageSource.gallery),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.plum,
                                    side: const BorderSide(color: AppColors.line),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.video_library_outlined, size: 18),
                                  label: Text(
                                    'From Gallery',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    '4. ADDITIONAL REASON DETAILS / NOTES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.plum,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Explain the return/refund reason or parcel condition...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),

          // Submit Footer: "Confirm Item in Hand" or "Returned to Hub"
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
                onPressed: _submitting
                    ? null
                    : (_isReturnClaim
                        ? (widget.parcel.stage == DeliveryStage.returningToHub
                            ? _submitReturnedToHub
                            : _submitItemInHand)
                        : _submitAction),
                style: FilledButton.styleFrom(
                  backgroundColor: _isReturnClaim
                      ? (widget.parcel.stage == DeliveryStage.returningToHub
                          ? AppColors.plum
                          : AppColors.orange)
                      : (_isReschedule ? AppColors.orange : AppColors.failed),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(_isReturnClaim
                        ? (widget.parcel.stage == DeliveryStage.returningToHub
                            ? Icons.warehouse_outlined
                            : Icons.front_hand_outlined)
                        : (_isReschedule ? Icons.update : Icons.assignment_return_outlined)),
                label: Text(
                  _submitting
                      ? (_isReturnClaim
                          ? (widget.parcel.stage == DeliveryStage.returningToHub
                              ? 'Handing in to Hub...'
                              : 'Confirming Item in Hand...')
                          : 'Submitting Return / Refund...')
                      : (_isReturnClaim
                          ? (widget.parcel.stage == DeliveryStage.returningToHub
                              ? 'Returned to Hub'
                              : 'Confirm Item in Hand')
                          : (_isReschedule ? 'Confirm Reschedule' : 'Submit Return / Refund')),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerEvidenceCard(BuildContext context) {
    final evidenceUrls = widget.parcel.resolvedReturnEvidenceUrls;

    if (evidenceUrls.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            const Icon(Icons.photo_library_outlined, size: 36, color: AppColors.muted),
            const SizedBox(height: 8),
            Text(
              'No buyer photo/video attached',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The buyer did not upload photos or video with this return claim.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
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
              const Icon(Icons.photo_camera_outlined, size: 16, color: AppColors.plum),
              const SizedBox(width: 6),
              Text(
                'Buyer Evidence (${evidenceUrls.length} file${evidenceUrls.length > 1 ? 's' : ''})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.plum,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to expand',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: evidenceUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final raw = evidenceUrls[idx];
                final isVideo = raw.toLowerCase().endsWith('.mp4') ||
                    raw.toLowerCase().endsWith('.mov') ||
                    raw.toLowerCase().contains('video');

                return GestureDetector(
                  onTap: () => _openLightbox(context, raw),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildMediaImage(raw, fit: BoxFit.cover),
                        ),
                      ),
                      if (isVideo)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.play_arrow, color: AppColors.plum, size: 24),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVideo ? Icons.videocam : Icons.zoom_in,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isVideo ? 'VID' : 'IMG',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
