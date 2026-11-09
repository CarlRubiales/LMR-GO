import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/mock_backend.dart';
import '../theme/app_colors.dart';

class RiderDateSelector extends StatelessWidget {
  const RiderDateSelector({
    super.key,
    this.onDateChanged,
  });

  final ValueChanged<DateTime>? onDateChanged;

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String _formatDate(DateTime dt) {
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.plum,
              onPrimary: AppColors.cream,
              surface: AppColors.cream,
              onSurface: AppColors.ink,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.cream,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      MockBackend().setSelectedDate(picked);
      onDateChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: MockBackend().selectedDateNotifier,
      builder: (context, selectedDate, _) {
        final isToday = _isToday(selectedDate);
        final formattedDate = _formatDate(selectedDate);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.plum.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top items: Title, Badge, and Calendar Button all wrap cleanly
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Manifest — $formattedDate',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.plum,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF5EE),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFB3DCBE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E6B37),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Live Queue",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1E6B37),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3D6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFF5D38A)),
                      ),
                      child: Text(
                        "📅 Archive",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8A5600),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  // Calendar Date Picker Button
                  InkWell(
                    onTap: () => _pickDate(context, selectedDate),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 15,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Pick Date',
                            style: GoogleFonts.inter(
                              color: AppColors.plum,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Bottom status text & Jump to Today button
              Text(
                isToday
                    ? "Showing today's run. Rolls over automatically at 12:00 AM PHT."
                    : "Showing archived run for $formattedDate. Historical records preserved.",
                style: GoogleFonts.inter(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),

              if (!isToday) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    MockBackend().jumpToToday();
                    onDateChanged?.call(DateTime.now());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.plum,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Jump to Today →',
                      style: GoogleFonts.inter(
                        color: AppColors.cream,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
