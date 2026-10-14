import 'package:flutter/material.dart';

import '../models/rider_account.dart';
import 'account_widgets.dart';

class PayoutPreferencesScreen extends StatefulWidget {
  const PayoutPreferencesScreen({super.key, required this.account});
  final RiderAccount account;
  @override
  State<PayoutPreferencesScreen> createState() =>
      _PayoutPreferencesScreenState();
}

class _PayoutPreferencesScreenState extends State<PayoutPreferencesScreen> {
  Future<void> edit([int? index]) async {
    final result = await Navigator.push<PreviewPayout>(
      context,
      MaterialPageRoute(
        builder: (_) => _PayoutEditor(
          existing: index == null ? null : widget.account.payouts[index],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => widget.account.savePayout(result, index: index));
      accountFeedback(
        context,
        'Masked payout preview saved. No payout account was connected.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Payout preferences',
    children: [
      const PreviewNotice(
        text: 'Preview only. Use sample details. Only the last four digits are retained; no payout account is connected.',
      ),
      if (widget.account.payouts.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No payout methods yet.'),
        ),
      for (final entry in widget.account.payouts.asMap().entries)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.value.type,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (entry.value.bank.isNotEmpty) Text(entry.value.bank),
                Text(entry.value.name),
                Text(entry.value.maskedNumber),
                if (entry.value.isDefault) const Chip(label: Text('Default')),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: () => edit(entry.key),
                      child: const Text('Edit'),
                    ),
                    if (!entry.value.isDefault)
                      TextButton(
                        onPressed: () {
                          setState(
                            () => widget.account.setDefault(entry.value),
                          );
                          accountFeedback(
                            context,
                            'Default preview method updated.',
                          );
                        },
                        child: const Text('Set as default'),
                      ),
                    TextButton(
                      onPressed: () async {
                        final confirmed = await accountConfirm(
                          context,
                          'Remove payout method?',
                          'Remove this masked payout method from your local preview?',
                          'Remove',
                        );
                        if (confirmed && mounted && context.mounted) {
                          setState(
                            () => widget.account.removePayout(entry.value),
                          );
                          accountFeedback(context, 'Payout preview removed.');
                        }
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add payout method'),
      ),
    ],
  );
}

class _PayoutEditor extends StatefulWidget {
  const _PayoutEditor({this.existing});
  final PreviewPayout? existing;
  @override
  State<_PayoutEditor> createState() => _PayoutEditorState();
}

class _PayoutEditorState extends State<_PayoutEditor> {
  final form = GlobalKey<FormState>();
  late String type = widget.existing?.type ?? 'GCash';
  late final name = TextEditingController(text: widget.existing?.name);
  late final bank = TextEditingController(text: widget.existing?.bank);
  final number = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    bank.dispose();
    number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Payout method',
    children: [
      const PreviewNotice(
        text: 'Use sample details. Full numbers are discarded when you save or leave this screen.',
      ),
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Payout type'),
              items: ['GCash', 'Maya', 'Bank account']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                type = value!;
                number.clear();
              }),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Account name'),
              maxLength: 100,
              validator: requiredText,
            ),
            if (type == 'Bank account') ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: bank,
                decoration: const InputDecoration(labelText: 'Bank name'),
                maxLength: 100,
                validator: requiredText,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: number,
              keyboardType: TextInputType.phone,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: type == 'Bank account'
                    ? 'Account number'
                    : 'Mobile number',
                helperText: widget.existing == null
                    ? null
                    : 'Re-enter a sample number to save changes.',
              ),
              validator: (value) {
                if (type != 'Bank account') return phoneError(value);
                return RegExp(r'^\d{6,20}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter 6–20 digits';
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                final digits = number.text.replaceAll(RegExp(r'\D'), '');
                final result = PreviewPayout(
                  type: type,
                  name: name.text.trim(),
                  lastFour: digits.substring(digits.length - 4),
                  bank: type == 'Bank account' ? bank.text.trim() : '',
                );
                number.clear();
                Navigator.pop(context, result);
              },
              child: const Text('Save preview'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ],
  );
}
