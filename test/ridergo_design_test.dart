import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/login_screen.dart';
import 'package:flutter_app/screens/registration_screen.dart';

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  for (final size in [
    const Size(320, 740),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    testWidgets('login layout and callbacks at ${size.width}', (tester) async {
      viewport(tester, size);
      var signedIn = 0;
      var registered = 0;
      var backed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            onBack: () => backed++,
            onLogin: () => signedIn++,
            onRegister: () => registered++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('LMR GO'), findsOneWidget);
      expect(
        find.text('Ride Smarter.\nDeliver Better.'),
        size.width >= 900 ? findsOneWidget : findsNothing,
      );
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse,
      );
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      expect(signedIn, 1);
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      expect(registered, 1);
      await tester.ensureVisible(find.text('Back'));
      await tester.tap(find.text('Back'));
      expect(backed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('registration retains validation at ${size.width}', (
      tester,
    ) async {
      viewport(tester, size);
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RegistrationScreen(
            onBack: () {},
            onLogin: () {},
            onSubmitted: () => submitted = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Submit registration'));
      await tester.tap(find.text('Submit registration'));
      await tester.pumpAndSettle();
      expect(submitted, isFalse);
      expect(find.text('Required'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all RiderGo tabs fit at ${size.width}', (tester) async {
      viewport(tester, size);
      await tester.pumpWidget(const RiderGoApp());
      await tester.pumpAndSettle();
      for (final label in [
        'Home',
        'Deliveries',
        'Chat',
        'Account',
      ]) {
        final destination = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );
        await tester.tap(destination);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets('login stays scrollable with keyboard and enlarged text', (
    tester,
  ) async {
    viewport(tester, const Size(360, 800));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: LoginScreen(onBack: null, onLogin: () {}, onRegister: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text('Sign in')).dy,
      lessThanOrEqualTo(500),
    );
    expect(tester.takeException(), isNull);
  });
}
