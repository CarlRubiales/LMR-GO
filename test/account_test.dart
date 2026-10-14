import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/rider_account.dart';
import 'package:flutter_app/screens/account_screen.dart';
import 'package:flutter_app/screens/profile_screens.dart';
import 'package:flutter_app/screens/payout_preferences_screen.dart';

void main() {
  test('payout defaults stay unique after edit and removal', () {
    final account = RiderAccount();
    final a = PreviewPayout(type: 'GCash', name: 'Sample', lastFour: '1234');
    final b = PreviewPayout(type: 'Maya', name: 'Sample', lastFour: '5678');
    account.savePayout(a);
    account.savePayout(b);
    expect(a.isDefault, isTrue);
    expect(b.isDefault, isFalse);
    account.setDefault(b);
    expect(account.payouts.where((p) => p.isDefault).length, 1);
    final edited = PreviewPayout(
      type: 'Bank account',
      name: 'Updated',
      lastFour: '9876',
    );
    account.savePayout(edited, index: 1);
    expect(edited.isDefault, isTrue);
    account.removePayout(edited);
    expect(a.isDefault, isTrue);
    expect(a.maskedNumber, '•••• •••• 1234');
  });

  test('expiry overrides review status without prematurely expiring today', () {
    final doc = RiderDocument('License', requiresExpiry: true);
    doc.reviewStatus = DocumentStatus.verified;
    final now = DateTime.now();
    doc.expires = DateTime(now.year, now.month, now.day);
    expect(doc.status, DocumentStatus.verified);
    expect(doc.expiringSoon, isTrue);
    doc.expires = DateTime(now.year, now.month, now.day - 1);
    expect(doc.status, DocumentStatus.expired);
    expect(RiderAccount().effectiveVerification, VerificationStatus.incomplete);
  });

  test('profile validators reject invalid phone and email values', () {
    expect(phoneError('09123456789'), isNull);
    expect(phoneError('+639123456789'), isNull);
    expect(phoneError('123'), isNotNull);
    expect(emailError('rider@example.com'), isNull);
    expect(emailError('rider@'), isNotNull);
    expect(requiredText('   '), isNotNull);
  });

  testWidgets('profile saves into the same account and updates its header', (
    tester,
  ) async {
    final account = RiderAccount();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountScreen(
            account: account,
            onRegister: () {},
            onLogin: () {},
            onSupport: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    Finder textField(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tester.enterText(textField('First name'), 'Jamie');
    await tester.enterText(textField('Mobile number'), '09123456789');
    await tester.enterText(textField('Email'), 'jamie@example.com');
    await tester.enterText(textField('Address'), 'Sample street');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Jamie A. Rivera'), findsOneWidget);
    expect(account.profile['Email'], 'jamie@example.com');
  });

  testWidgets('payout entry retains only the last four digits', (tester) async {
    final account = RiderAccount();
    await tester.pumpWidget(
      MaterialApp(home: PayoutPreferencesScreen(account: account)),
    );
    await tester.tap(find.text('Add payout method'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sample Rider');
    await tester.enterText(fields.at(1), '09123456789');
    await tester.ensureVisible(find.text('Save preview'));
    await tester.tap(find.text('Save preview'));
    await tester.pumpAndSettle();
    expect(account.payouts.single.lastFour, '6789');
    expect(find.text('•••• •••• 6789'), findsOneWidget);
    expect(find.text('09123456789'), findsNothing);
  });

  testWidgets('account controls fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountScreen(
            account: RiderAccount(),
            onRegister: () {},
            onLogin: () {},
            onSupport: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
