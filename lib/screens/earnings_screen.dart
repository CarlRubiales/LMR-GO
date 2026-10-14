import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../services/mock_backend.dart';
import '../widgets/app_page.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Earnings',
    subtitle: 'A clear view of your financial growth',
    child: FutureBuilder<Map<String, String>>(
      future: MockBackend().getEarnings(),
      builder: (_, snap) {
        final data = snap.data ?? const {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.plum,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.plum.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AVAILABLE BALANCE',
                    style: GoogleFonts.inter(
                      color: AppColors.blush2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['balance'] ?? 'Loading…',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.cream,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Next payout · Friday, Aug 29',
                    style: GoogleFonts.inter(
                      color: AppColors.blush1,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cream,
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      'Payout settings',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Performance snapshot'),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons.local_shipping_outlined,
                    value: '32',
                    label: 'Deliveries',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    icon: Icons.star_border,
                    value: '4.9',
                    label: 'Rating',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    icon: Icons.timer_outlined,
                    value: '96%',
                    label: 'On-time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              color: AppColors.cream,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.line),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.blush1,
                  child: Icon(Icons.history, color: AppColors.orange),
                ),
                title: Text(
                  'View delivery history',
                  style: GoogleFonts.inter(
                    color: AppColors.plum,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Review every completed trip and trip fee',
                  style: GoogleFonts.inter(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(
          color: AppColors.plum.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.plum,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}
