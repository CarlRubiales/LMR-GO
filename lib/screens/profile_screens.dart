import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/rider_account.dart';
import 'account_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.account});
  final RiderAccount account;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields = {
    for (final item in widget.account.profile.entries)
      item.key: TextEditingController(text: item.value),
  };
  late Uint8List? photo = widget.account.photo;
  bool busy = false;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false) || busy) return;
    setState(() => busy = true);
    try {
      widget.account.profile.addAll(
        fields.map((key, value) => MapEntry(key, value.text.trim())),
      );
      widget.account.photo = photo;
      if (mounted) {
        accountFeedback(context, 'Profile saved for this preview.');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        accountFeedback(
          context,
          'Unable to save your profile. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Edit profile',
    children: [
      const PreviewNotice(),
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage: photo == null ? null : MemoryImage(photo!),
                child: photo == null ? Text(widget.account.initials) : null,
              ),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final selected = await chooseAccountPhoto(context);
                      if (mounted) {
                        setState(() {
                          if (selected != null) photo = selected;
                          busy = false;
                        });
                      }
                    },
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Change profile photo'),
            ),
            if (photo != null)
              TextButton(
                onPressed: busy ? null : () => setState(() => photo = null),
                child: const Text('Remove photo'),
              ),
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: entry.value,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    hintText: entry.key == 'Birth date' ? 'YYYY-MM-DD' : null,
                  ),
                  keyboardType: entry.key == 'Email'
                      ? TextInputType.emailAddress
                      : entry.key.toLowerCase().contains('number')
                      ? TextInputType.phone
                      : TextInputType.text,
                  maxLength: entry.key == 'Address' ? 300 : 100,
                  validator: (value) {
                    if (entry.key == 'Email') return emailError(value);
                    if (entry.key == 'Mobile number') return phoneError(value);
                    if (entry.key == 'Emergency contact number') {
                      return phoneError(
                        value,
                        required: fields['Emergency contact name']!.text
                            .trim()
                            .isNotEmpty,
                      );
                    }
                    if (entry.key == 'Emergency contact name' &&
                        fields['Emergency contact number']!.text
                            .trim()
                            .isNotEmpty) {
                      return requiredText(value);
                    }
                    if ([
                      'First name',
                      'Last name',
                      'Address',
                    ].contains(entry.key)) {
                      return requiredText(value);
                    }
                    if (entry.key == 'Birth date' && value!.trim().isNotEmpty) {
                      final date = DateTime.tryParse(value.trim());
                      if (date == null ||
                          dateLabel(date) != value.trim() ||
                          date.isAfter(DateTime.now()) ||
                          date.year < 1900) {
                        return 'Enter a valid past date: YYYY-MM-DD';
                      }
                    }
                    return null;
                  },
                ),
              ),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy ? null : save,
              child: const Text('Save changes'),
            ),
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ],
  );
}

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key, required this.account});
  final RiderAccount account;
  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Personal information',
    children: [
      const PreviewNotice(),
      accountDetail('Full name', widget.account.fullName),
      accountDetail('Rider ID', widget.account.riderId),
      for (final item in widget.account.profile.entries)
        if (!['First name', 'Middle name', 'Last name'].contains(item.key))
          accountDetail(item.key, item.value),
      accountDetail('Account creation date', dateLabel(widget.account.joined)),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EditProfileScreen(account: widget.account),
            ),
          );
          if (mounted) setState(() {});
        },
        child: const Text('Edit information'),
      ),
      TextButton(
        onPressed: () async {
          final confirmed = await accountConfirm(
            context,
            'Delete your LMR GO account?',
            'Permanent account deletion requires a connected account service. This preview cannot delete a real account.',
            'Continue',
          );
          if (confirmed && context.mounted) {
            await accountInfo(
              context,
              'Account deletion unavailable',
              'No account exists on a server yet. Nothing was deleted. Log out to clear the local preview data.',
            );
          }
        },
        child: const Text('Delete account'),
      ),
    ],
  );
}
