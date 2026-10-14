import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/rider_account.dart';
import '../theme/app_colors.dart';
import 'account_widgets.dart';

class VehicleDocumentsScreen extends StatefulWidget {
  const VehicleDocumentsScreen({super.key, required this.account});
  final RiderAccount account;
  @override
  State<VehicleDocumentsScreen> createState() => _VehicleDocumentsScreenState();
}

class _VehicleDocumentsScreenState extends State<VehicleDocumentsScreen> {
  final form = GlobalKey<FormState>();
  late final fields = {
    for (final e in widget.account.vehicle.entries)
      e.key: TextEditingController(text: e.value),
  };
  bool busy = false;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void saveVehicle() {
    if (!(form.currentState?.validate() ?? false)) return;
    widget.account.vehicle.addAll(
      fields.map((k, v) => MapEntry(k, v.text.trim())),
    );
    widget.account.verification = VerificationStatus.incomplete;
    accountFeedback(context, 'Vehicle details saved locally.');
    setState(() {});
  }

  Future<void> pick(RiderDocument document) async {
    setState(() => busy = true);
    final photo = await chooseAccountPhoto(context);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (photo != null) {
        document.image = photo;
        document.reviewStatus = DocumentStatus.selected;
        widget.account.verification = VerificationStatus.incomplete;
      }
    });
  }

  Future<void> setDate(RiderDocument document, bool expiry) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: (expiry ? document.expires : document.issued) ?? now,
      firstDate: DateTime(1900),
      lastDate: expiry ? DateTime(now.year + 30) : now,
    );
    if (!mounted || result == null) return;
    if ((expiry &&
            document.issued != null &&
            result.isBefore(document.issued!)) ||
        (!expiry &&
            document.expires != null &&
            result.isAfter(document.expires!))) {
      accountFeedback(
        context,
        'Expiration must be on or after the issue date.',
      );
      return;
    }
    setState(() {
      if (expiry) {
        document.expires = result;
      } else {
        document.issued = result;
      }
      if (document.image != null) {
        document.reviewStatus = DocumentStatus.selected;
      }
      widget.account.verification = VerificationStatus.incomplete;
    });
  }

  @override
  Widget build(BuildContext context) => AccountPage(
    title: 'Vehicle & documents',
    children: [
      const PreviewNotice(
        text: 'Images stay in memory for this preview. Nothing is uploaded or sent for approval.',
      ),
      Form(
        key: form,
        child: Column(
          children: [
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: entry.value,
                  decoration: InputDecoration(labelText: entry.key),
                  maxLength: 80,
                  keyboardType: entry.key == 'Year model'
                      ? TextInputType.number
                      : TextInputType.text,
                  validator: (value) {
                    if (requiredText(value) != null) {
                      return 'This field is required';
                    }
                    if (entry.key == 'Year model') {
                      final year = int.tryParse(value!.trim());
                      if (year == null ||
                          year < 1950 ||
                          year > DateTime.now().year + 1) {
                        return 'Enter a valid model year';
                      }
                    }
                    return null;
                  },
                ),
              ),
          ],
        ),
      ),
      FilledButton(
        onPressed: busy ? null : saveVehicle,
        child: const Text('Save vehicle details'),
      ),
      const SizedBox(height: 22),
      Text(
        'Rider documents',
        style: GoogleFonts.playfairDisplay(
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      if (busy) const LinearProgressIndicator(),
      for (final document in widget.account.documents)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  document.expiringSoon
                      ? '${document.statusLabel} · Expiring soon'
                      : document.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: switch (document.status) {
                      DocumentStatus.expired ||
                      DocumentStatus.rejected => AppColors.failed,
                      DocumentStatus.pending => AppColors.pending,
                      DocumentStatus.verified =>
                        document.expiringSoon
                            ? AppColors.pending
                            : AppColors.delivered,
                      DocumentStatus.selected => AppColors.orange,
                      DocumentStatus.notUploaded => AppColors.muted,
                    },
                  ),
                ),
                if (document.requiresExpiry) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date issued'),
                    subtitle: Text(dateLabel(document.issued)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: busy ? null : () => setDate(document, false),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiration date'),
                    subtitle: Text(dateLabel(document.expires)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: busy ? null : () => setDate(document, true),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => pick(document),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(
                        document.image == null
                            ? 'Add photo'
                            : 'Replace / retake',
                      ),
                    ),
                    if (document.image != null)
                      TextButton(
                        onPressed: () => viewAccountPhoto(
                          context,
                          document.image!,
                          document.name,
                        ),
                        child: const Text('View'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: busy
            ? null
            : () {
                if (!(form.currentState?.validate() ?? false)) return;
                final docs = widget.account.documents;
                if (docs.any(
                  (d) =>
                      d.image == null ||
                      d.status == DocumentStatus.expired ||
                      (d.requiresExpiry &&
                          (d.issued == null || d.expires == null)),
                )) {
                  accountFeedback(
                    context,
                    'Add all document photos and valid issue/expiration dates first.',
                  );
                  return;
                }
                widget.account.vehicle.addAll(
                  fields.map((k, v) => MapEntry(k, v.text.trim())),
                );
                setState(() {
                  for (final doc in docs) {
                    doc.reviewStatus = DocumentStatus.pending;
                  }
                  widget.account.verification = VerificationStatus.pending;
                });
                accountFeedback(
                  context,
                  'Review preview prepared. No documents were submitted.',
                );
              },
        child: const Text('Preview verification submission'),
      ),
    ],
  );
}
