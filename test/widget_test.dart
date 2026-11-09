import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/splash_screen.dart';

void main() {
  testWidgets('LMR GO app builds and shows animated splash screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const LmrGoApp());

    expect(find.text('LUMORA GO'), findsOneWidget);
    expect(find.text('EXPRESS'), findsOneWidget);
    expect(find.text('“Move Beautifully, Deliver Calmly.”'), findsOneWidget);
  });

  testWidgets('SplashScreen finishes animation and triggers onFinish callback', (WidgetTester tester) async {
    bool finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          animationDuration: const Duration(milliseconds: 300),
          stayDuration: const Duration(milliseconds: 100),
          onFinish: () => finished = true,
        ),
      ),
    );

    expect(find.text('LUMORA GO'), findsOneWidget);
    expect(find.text('EXPRESS'), findsOneWidget);

    // Let entrance animation and transition timer complete
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));

    expect(finished, isTrue);
  });
}
