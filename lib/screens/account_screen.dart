import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../models/rider_account.dart';
import '../widgets/app_page.dart';
import 'account_widgets.dart';
import 'profile_screens.dart';
import 'vehicle_documents_screen.dart';
import 'payout_preferences_screen.dart';
import 'help_center_screen.dart';
import 'account_settings_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.account,
    required this.onRegister,
    required this.onLogin,
    required this.onSupport,
  });

  final RiderAccount account;
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  final VoidCallback onSupport;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final statusColor = switch (account.effectiveVerification) {
      VerificationStatus.verified => AppColors.delivered,
      VerificationStatus.pending => AppColors.pending,
      VerificationStatus.rejected ||
      VerificationStatus.suspended => AppColors.failed,
      VerificationStatus.incomplete => AppColors.muted,
    };
    final settings = <(String, IconData, Widget)>[
      (
        'Personal information',
        Icons.person_outline,
        PersonalInformationScreen(account: account),
      ),
      (
        'Vehicle & documents',
        Icons.description_outlined,
        VehicleDocumentsScreen(account: account),
      ),
      (
        'Payout preferences',
        Icons.account_balance_wallet_outlined,
        PayoutPreferencesScreen(account: account),
      ),
      (
        'Help center',
        Icons.help_outline,
        HelpCenterScreen(onSupport: widget.onSupport),
      ),
      (
        'Settings',
        Icons.settings_outlined,
        AccountSettingsScreen(account: account),
      ),
    ];
    return AppPage(
      title: 'Account',
      subtitle: 'Your rider profile and settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.cream,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.line),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.plum,
                backgroundImage: account.photo == null
                    ? null
                    : MemoryImage(account.photo!),
                child: account.photo == null
                    ? Text(
                        account.initials.isEmpty ? 'R' : account.initials,
                        style: GoogleFonts.inter(
                          color: AppColors.cream,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              title: Text(
                account.fullName,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.plum,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Rider since ${dateLabel(account.joined)} · ${account.riderId}',
                style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11),
              ),
              trailing: IconButton(
                tooltip: 'Edit profile',
                onPressed: () => open(EditProfileScreen(account: account)),
                icon: const Icon(Icons.edit, color: AppColors.orange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => open(VehicleDocumentsScreen(account: account)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      account.effectiveVerification ==
                              VerificationStatus.verified
                          ? Icons.verified_user
                          : Icons.assignment_outlined,
                      color: statusColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.verificationTitle,
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.verificationDescription,
                            style: GoogleFonts.inter(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.cream,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (final item in settings)
                  ListTile(
                    onTap: () => open(item.$3),
                    leading: Icon(item.$2, color: AppColors.orange),
                    title: Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        color: AppColors.plum,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Want to join as a rider?'),
          Card(
            color: AppColors.cream,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register another rider account',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.plum,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Submit personal details, vehicle information, and verification documents.',
                    style: GoogleFonts.inter(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () async {
                      final confirmed = await accountConfirm(
                        context,
                        'Open registration preview?',
                        'This opens the existing LMR GO form. It does not create another real account or submit an application.',
                        'Open registration',
                      );
                      if (confirmed && mounted) widget.onRegister();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.plum,
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Open registration'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              final confirmed = await accountConfirm(
                context,
                'Log out of LMR GO?',
                'Clear your local profile changes, selected photos, payout previews, preferences, and chat messages?',
                'Log out',
              );
              if (confirmed && mounted) widget.onLogin();
            },
            icon: const Icon(Icons.logout, color: AppColors.failed),
            label: Text(
              'Log out',
              style: GoogleFonts.inter(
                color: AppColors.failed,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const PreviewNotice(
            text: 'Sample rider · no authenticated account is connected. Changes last for this session.',
          ),
        ],
      ),
    );
  }
}
