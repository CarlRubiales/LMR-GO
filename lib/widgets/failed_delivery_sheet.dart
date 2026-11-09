import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/delivery_request.dart';
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
                        (widget.isPostDelivery || widget.parcel.isDelivered)
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

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                if (widget.isPostDelivery || widget.parcel.isDelivered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.failedSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_return_outlined, size: 18, color: AppColors.failed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Post-Delivery Return / Refund Request',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.failed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Action Toggle: Return/Refund vs Reschedule
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

                // 1. Reason Selection
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

                // Reschedule Time Window Selection (if Reschedule tab selected)
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

                // 2. Picture (Photo) Evidence
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

                // 3. Video Evidence
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

                // 4. Additional Reason Details / Notes
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
            ),
          ),

          // Submit Footer
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
                onPressed: _submitting ? null : _submitAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _isReschedule ? AppColors.orange : AppColors.failed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(_isReschedule ? Icons.update : Icons.assignment_return_outlined),
                label: Text(
                  _submitting
                      ? 'Submitting Return / Refund...'
                      : (_isReschedule ? 'Confirm Reschedule' : 'Submit Return / Refund'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
