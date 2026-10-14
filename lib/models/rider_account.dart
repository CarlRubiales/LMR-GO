import 'dart:typed_data';

enum VerificationStatus { verified, pending, rejected, suspended, incomplete }

enum DocumentStatus {
  verified,
  pending,
  rejected,
  expired,
  notUploaded,
  selected,
}

class RiderDocument {
  RiderDocument(this.name, {this.requiresExpiry = false});
  final String name;
  final bool requiresExpiry;
  Uint8List? image;
  DateTime? issued;
  DateTime? expires;
  DocumentStatus reviewStatus = DocumentStatus.notUploaded;

  DocumentStatus get status {
    final now = DateTime.now();
    if (expires != null &&
        expires!.isBefore(DateTime(now.year, now.month, now.day))) {
      return DocumentStatus.expired;
    }
    return reviewStatus;
  }

  bool get expiringSoon =>
      expires != null &&
      status != DocumentStatus.expired &&
      expires!.difference(DateTime.now()).inDays <= 30;

  String get statusLabel => switch (status) {
    DocumentStatus.verified => 'Verified',
    DocumentStatus.pending => 'Pending · preview',
    DocumentStatus.rejected => 'Rejected',
    DocumentStatus.expired => 'Expired',
    DocumentStatus.notUploaded => 'Not uploaded',
    DocumentStatus.selected => 'Selected locally',
  };
}

class PreviewPayout {
  PreviewPayout({
    required this.type,
    required this.name,
    required this.lastFour,
    this.bank = '',
    this.isDefault = false,
  });
  final String type;
  final String name;
  final String lastFour;
  final String bank;
  bool isDefault;
  String get maskedNumber => '•••• •••• $lastFour';
}

/// Local preview data. No credentials or complete payout numbers are stored.
class RiderAccount {
  final Map<String, String> profile = {
    'First name': 'Alex',
    'Middle name': 'A.',
    'Last name': 'Rivera',
    'Mobile number': '',
    'Email': '',
    'Address': '',
    'Emergency contact name': '',
    'Emergency contact number': '',
    'Birth date': '',
    'Gender': '',
  };
  final Map<String, String> vehicle = {
    'Vehicle type': 'Motorcycle',
    'Brand': '',
    'Model': '',
    'Color': '',
    'Plate number': '',
    'Year model': '',
  };
  final String riderId = 'RG-00482';
  final DateTime joined = DateTime(2026, 8, 1);
  Uint8List? photo;
  VerificationStatus verification = VerificationStatus.incomplete;
  final documents = [
    RiderDocument('Driver’s license', requiresExpiry: true),
    RiderDocument('OR/CR'),
    RiderDocument('Vehicle registration', requiresExpiry: true),
    RiderDocument('Valid ID'),
    RiderDocument('Rider photo'),
  ];
  final List<PreviewPayout> payouts = [];
  final Map<String, bool> notifications = {
    'Delivery notifications': true,
    'Chat notifications': true,
    'Earnings notifications': true,
    'Promotions': false,
    'System updates': true,
  };

  String get fullName => ['First name', 'Middle name', 'Last name']
      .map((key) => profile[key]!.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');
  String get initials => ['First name', 'Last name']
      .map((key) => profile[key]!.trim())
      .where((value) => value.isNotEmpty)
      .map((value) => String.fromCharCode(value.runes.first))
      .join()
      .toUpperCase();
  VerificationStatus get effectiveVerification {
    if (verification == VerificationStatus.suspended) return verification;
    if (documents.any(
      (d) =>
          d.status == DocumentStatus.expired ||
          d.status == DocumentStatus.notUploaded ||
          d.status == DocumentStatus.selected,
    )) {
      return VerificationStatus.incomplete;
    }
    if (documents.any((d) => d.status == DocumentStatus.rejected)) {
      return VerificationStatus.rejected;
    }
    return verification;
  }

  String get verificationTitle => switch (effectiveVerification) {
    VerificationStatus.verified => 'Account verified',
    VerificationStatus.pending => 'Verification pending · preview',
    VerificationStatus.rejected => 'Verification failed',
    VerificationStatus.suspended => 'Account suspended',
    VerificationStatus.incomplete => 'Verification incomplete',
  };
  String get verificationDescription => switch (effectiveVerification) {
    VerificationStatus.verified => 'Your documents are approved and active.',
    VerificationStatus.pending =>
      'Local review preview. Nothing has been submitted.',
    VerificationStatus.rejected => 'Some documents need your attention.',
    VerificationStatus.suspended => 'Contact support for details.',
    VerificationStatus.incomplete =>
      'Add your vehicle details and required documents.',
  };

  void savePayout(PreviewPayout payout, {int? index}) {
    if (index == null) {
      payout.isDefault = payouts.isEmpty;
      payouts.add(payout);
    } else {
      payout.isDefault = payouts[index].isDefault;
      payouts[index] = payout;
    }
  }

  void setDefault(PreviewPayout payout) {
    for (final item in payouts) {
      item.isDefault = identical(item, payout);
    }
  }

  void removePayout(PreviewPayout payout) {
    payouts.remove(payout);
    if (payouts.isNotEmpty && !payouts.any((p) => p.isDefault)) {
      payouts.first.isDefault = true;
    }
  }
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;

String? phoneError(String? value, {bool required = true}) {
  final text = (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
  if (text.isEmpty) return required ? 'Enter a mobile number' : null;
  return RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(text)
      ? null
      : 'Use 09XXXXXXXXX or +639XXXXXXXXX';
}

String? emailError(String? value) {
  if (requiredText(value) != null) return 'Enter an email address';
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
      ? null
      : 'Enter a valid email address';
}

String dateLabel(DateTime? date) => date == null
    ? 'Not provided'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
