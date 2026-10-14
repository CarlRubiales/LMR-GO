import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/chat_screen.dart';
import 'package:flutter_app/screens/conversation_screen.dart';

void main() {
  Future<void> openMessages(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search filters conversations and clear restores them', (
    tester,
  ) async {
    await openMessages(tester);
    await tester.enterText(find.byType(TextField), 'Support');
    await tester.pump();
    expect(find.text('LMR GO Support'), findsOneWidget);
    expect(find.text('Mango Tree Grocer'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Mango Tree Grocer'), findsOneWidget);
  });

  testWidgets(
    'send stays local, trims text and updates the conversation preview',
    (tester) async {
      await openMessages(tester);
      await tester.tap(find.text('LMR GO Support'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Send message',
        ),
      );
      expect(button.onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  On my way!  ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('On my way!'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('You: On my way!'), findsOneWidget);
      final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((rows.first.title! as Text).data, 'LMR GO Support');
    },
  );

  testWidgets('opening an unread conversation clears its local badge', (
    tester,
  ) async {
    await openMessages(tester);
    await tester.tap(find.text('Unread'));
    await tester.pump();
    expect(find.text('Mango Tree Grocer'), findsOneWidget);
    expect(find.text('LMR GO Support'), findsNothing);
    await tester.tap(find.text('Mango Tree Grocer'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No unread messages.'), findsOneWidget);
  });

  testWidgets('composer fits a narrow screen with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await openMessages(tester);
    await tester.tap(find.text('Mango Tree Grocer'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(
      find.byType(TextField),
      'A longer message that should wrap correctly on a narrow phone screen.',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byTooltip('Send message')).dy,
      lessThanOrEqualTo(480),
    );
  });
}
