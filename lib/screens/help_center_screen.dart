import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'account_widgets.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key, required this.onSupport});
  final VoidCallback onSupport;
  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Help center',
    children: [
      Text(
        'Frequently Asked Questions',
        style: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 12),
      for (final item in const [
        (
          'How do deliveries work?',
          'Open Deliveries to see sample requests. Accept a request and use the trip controls to preview pickup and delivery.',
        ),
        (
          'How do I receive earnings?',
          'Earnings currently shows sample amounts. Payout preferences lets you preview methods; it does not transfer money.',
        ),
        (
          'How do I change my vehicle?',
          'Open Account → Vehicle & documents, edit the details, then save. Changes apply locally.',
        ),
        (
          'How do I update my documents?',
          'Open Vehicle & documents to select or retake a photo. Add the issue and expiration dates where requested.',
        ),
        (
          'Why is my account pending verification?',
          'This preview can show a pending state after you prepare documents. Real review requires LMR GO’s account service.',
        ),
        (
          'What happens if my document expires?',
          'The document is labeled Expired and verification becomes incomplete. Replace it and update its dates.',
        ),
        (
          'How do I contact support?',
          'Use Chat with support below to open the existing LMR GO Support preview conversation. Live support is not connected yet.',
        ),
      ])
        Card(
          child: ExpansionTile(
            title: Text(item.$1, style: const TextStyle(fontSize: 13)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(item.$2),
              ),
            ],
          ),
        ),
      const SizedBox(height: 18),
      Text(
        'Contact LMR GO Support',
        style: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: const Text('Chat with support'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onSupport,
      ),
      ListTile(
        leading: const Icon(Icons.email_outlined),
        title: const Text('Email support'),
        onTap: () => accountInfo(
          context,
          'Email support',
          'An official LMR GO support email has not been configured. You can explore the support chat preview instead.',
        ),
      ),
      ListTile(
        leading: const Icon(Icons.call_outlined),
        title: const Text('Call support'),
        onTap: () => accountInfo(
          context,
          'Call support',
          'An official LMR GO support phone number has not been configured.',
        ),
      ),
    ],
  );
}
