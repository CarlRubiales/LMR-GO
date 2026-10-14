import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_colors.dart';
import '../models/rider_account.dart';
import 'account_widgets.dart';
import 'profile_screens.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.account});
  final RiderAccount account;
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final Future<PackageInfo> version = PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Account settings',
    children: [
      const PreviewNotice(
        text: 'Preferences apply to this local preview only. Push notifications are not connected.',
      ),
      Text(
        'Notifications',
        style: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      Card(
        child: Column(
          children: [
            for (final entry in widget.account.notifications.entries)
              SwitchListTile(
                title: Text(entry.key, style: const TextStyle(fontSize: 13)),
                value: entry.value,
                onChanged: (value) => setState(
                  () => widget.account.notifications[entry.key] = value,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('Language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => accountInfo(
                context,
                'Language',
                'English is currently available. Additional translations have not been configured.',
              ),
            ),
            ListTile(
              title: const Text('Privacy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => accountInfo(
                context,
                'Preview privacy',
                'Account changes and selected images stay in memory until logout or restart. Payout previews retain only the last four digits. No account data is sent to a server.',
              ),
            ),
            ListTile(
              title: const Text('Security'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _SecurityScreen(account: widget.account),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'About LMR GO',
        style: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      FutureBuilder<PackageInfo>(
        future: version,
        builder: (context, snapshot) => ListTile(
          title: const Text('App version'),
          subtitle: Text(
            snapshot.hasError
                ? 'Version unavailable'
                : snapshot.hasData
                ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                : 'Loading version…',
          ),
        ),
      ),
      ListTile(
        title: const Text('Terms and Conditions'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => accountInfo(
          context,
          'Terms and Conditions',
          'LMR GO’s official terms have not been provided. No published terms are linked in this preview.',
        ),
      ),
      ListTile(
        title: const Text('Privacy Policy'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => accountInfo(
          context,
          'Privacy Policy',
          'LMR GO’s official privacy policy has not been provided. No published policy is linked in this preview.',
        ),
      ),
    ],
  );
}

class _SecurityScreen extends StatelessWidget {
  const _SecurityScreen({required this.account});
  final RiderAccount account;
  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Security',
    children: [
      const PreviewNotice(
        text: 'This app currently has no authenticated accounts or password service.',
      ),
      for (final title in ['Change password', 'Manage active sessions'])
        ListTile(
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => accountInfo(
            context,
            title,
            'This requires a connected authentication service. No credentials or sessions were changed.',
          ),
        ),
      ListTile(
        title: const Text('Change email or mobile number'),
        subtitle: const Text('Edit local profile details'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => EditProfileScreen(account: account),
          ),
        ),
      ),
    ],
  );
}
