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
  });

  final DeliveryRequest parcel;
  final VoidCallback onFailedRecorded;

  @override
  State<FailedDeliverySheet> createState() => _FailedDeliverySheetState();
}

class _FailedDeliverySheetState extends State<FailedDeliverySheet> {
  static const List<String> _reasons = [
    'Customer Not Home',
    'Wrong Address / Unlocatable',
    'Customer Refused Parcel',
    'Unreachable / Phone Off',
    'Requested Reschedule',
    'Other Issue',
  ];

  String _selectedReason = _reasons.first;
  final TextEditingController _notesController = TextEditingController();
  String? _photoPath;
  bool _isSubmitting = false;

  // Reschedule options
  String _rescheduleDay = 'Tomorrow';
  String _rescheduleWindow = 'Morning (9 AM - 12 PM)';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      setState(() => _photoPath = 'simulated_failed_${widget.parcel.id}.jpg');
    }
  }

  Future<void> _submitAction({required bool isReschedule}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final stage = isReschedule ? DeliveryStage.rescheduled : DeliveryStage.returningToHub;
    final fullNotes = isReschedule
        ? 'Rescheduled for $_rescheduleDay ($_rescheduleWindow). Notes: ${_notesController.text.trim()}'
        : 'Returning to hub sorting bin. Notes: ${_notesController.text.trim()}';

    await MockBackend().updateParcelStatus(
      widget.parcel.id,
      stage,
      failureReason: _selectedReason,
      failureNotes: fullNotes,
      podPhotoPath: _photoPath,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onFailedRecorded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReschedule
                ? 'Parcel ${widget.parcel.id} rescheduled for $_rescheduleDay'
                : 'Parcel ${widget.parcel.id} marked Returning to Hub',
          ),
          backgroundColor: AppColors.failed,
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
                      'Report Delivery Issue',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.failed,
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
                Text(
                  'SELECT REASON FOR FAILED DELIVERY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.plum,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Reasons Chips / Radios
                for (final reason in _reasons)
                  InkWell(
                    onTap: () => setState(() => _selectedReason = reason),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedReason == reason ? AppColors.failedSoft : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedReason == reason ? AppColors.failed : AppColors.line,
                          width: _selectedReason == reason ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedReason == reason ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _selectedReason == reason ? AppColors.failed : AppColors.muted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reason,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _selectedReason == reason ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedReason == reason ? AppColors.failed : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Optional Photo of Gate/Doorstep
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.blush1,
                        child: const Icon(Icons.camera_alt_outlined, color: AppColors.plum, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _photoPath != null ? 'Doorstep Proof Captured' : 'Attach Photo Proof (Optional)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Closed gate, house number, or notice',
                              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _takePhoto,
                        child: Text(
                          _photoPath != null ? 'Retake' : 'Capture',
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
                const SizedBox(height: 12),

                // Rider Note field
                Text(
                  'ADDITIONAL NOTES / REMARKS',
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
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. Called 3x, gate locked, neighbor said at work...',
                    hintStyle: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reschedule Options Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.blush1,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_repeat, color: AppColors.plum, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'RESCHEDULE PREFERENCES',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.plum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _rescheduleDay,
                              decoration: InputDecoration(
                                labelText: 'Day',
                                labelStyle: GoogleFonts.inter(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: ['Tomorrow', 'In 2 Days', 'Next Monday']
                                  .map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.inter(fontSize: 12))))
                                  .toList(),
                              onChanged: (v) => setState(() => _rescheduleDay = v ?? 'Tomorrow'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _rescheduleWindow,
                              decoration: InputDecoration(
                                labelText: 'Time Window',
                                labelStyle: GoogleFonts.inter(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: ['Morning (9 AM - 12 PM)', 'Afternoon (1 PM - 5 PM)']
                                  .map((w) => DropdownMenuItem(value: w, child: Text(w, style: GoogleFonts.inter(fontSize: 10))))
                                  .toList(),
                              onChanged: (v) => setState(() => _rescheduleWindow = v ?? 'Morning (9 AM - 12 PM)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Two Action Buttons: Reschedule OR Return to Hub
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: !_isSubmitting ? () => _submitAction(isReschedule: true) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.plum,
                      foregroundColor: AppColors.cream,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.schedule_send, size: 18),
                    label: Text(
                      'Reschedule Delivery Run',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: !_isSubmitting ? () => _submitAction(isReschedule: false) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.failed,
                      side: const BorderSide(color: AppColors.failed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.keyboard_return, size: 18),
                    label: Text(
                      'Return Parcel to Hub Sorting Center',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
