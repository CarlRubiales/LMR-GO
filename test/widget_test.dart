import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('LMR GO app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const LmrGoApp());

    expect(find.text('LMR GO'), findsOneWidget);
  });
}
