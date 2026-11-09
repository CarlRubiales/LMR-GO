import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/delivery_request.dart';
import 'package:flutter_app/services/mock_backend.dart';
import 'package:flutter_app/widgets/eod_return_sheet.dart';

void main() {
  final undeliveredParcels = [
    DeliveryRequest(
      id: 'LMR-90001',
      store: 'Standard Delivery',
      pickup: 'Central Hub',
      dropoff: 'Brgy Sta Clara, Pila, Laguna',
      fee: '₱150.00',
      distance: '3.5 km',
      eta: '25 min',
      stage: DeliveryStage.failed,
      recipientName: 'Maria Santos',
      failureReason: 'Customer Unreachable / Not Home',
      codAmount: 1250.0,
      isCod: true,
    ),
    DeliveryRequest(
      id: 'LMR-90002',
      store: 'Standard Delivery',
      pickup: 'Central Hub',
      dropoff: 'Brgy Sta Clara, Pila, Laguna',
      fee: '₱150.00',
      distance: '3.5 km',
      eta: '25 min',
      stage: DeliveryStage.failed,
      recipientName: 'Juan Dela Cruz',
      failureReason: 'Damaged / Defective Item',
      codAmount: 2200.0,
      isCod: true,
    ),
  ];

  final deliveredParcels = [
    DeliveryRequest(
      id: 'LMR-80001',
      store: 'Standard Delivery',
      pickup: 'Central Hub',
      dropoff: 'Brgy Sta Clara, Pila, Laguna',
      fee: '₱150.00',
      distance: '3.5 km',
      eta: '25 min',
      stage: DeliveryStage.delivered,
      recipientName: 'Ana Gomez',
      codAmount: 3450.0,
      isCod: true,
    ),
  ];

  final widths = [320.0, 360.0, 412.0];
  final textScales = [1.0, 1.4];

  for (final width in widths) {
    for (final scale in textScales) {
      testWidgets('Renders undelivered state without overflow at ${width.toInt()}px, scale $scale', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800.0),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: EodReturnSheet(
                  allParcels: [...deliveredParcels, ...undeliveredParcels],
                  onComplete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero overflow exceptions
        expect(tester.takeException(), isNull);
        expect(find.text('End of Day Return & Remit'), findsOneWidget);
        expect(find.text('₱3,450.00'), findsOneWidget);
        expect(find.text('Confirm Hub Intake & Close Run'), findsOneWidget);
      });

      testWidgets('Renders all-delivered state without overflow at ${width.toInt()}px, scale $scale', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800.0),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: EodReturnSheet(
                  allParcels: deliveredParcels,
                  onComplete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero overflow exceptions
        expect(tester.takeException(), isNull);
        // Look up widgets allowing offstage (since the middle ListView scrolls smoothly)
        expect(find.text('All parcels delivered', skipOffstage: false), findsOneWidget);
        expect(find.text('Close Run'), findsOneWidget);

        // Scroll to the item to verify it scrolls into view cleanly
        await tester.scrollUntilVisible(find.text('All parcels delivered'), 50.0);
        await tester.pumpAndSettle();
        expect(find.text('All parcels delivered'), findsOneWidget);
      });
    }
  }

  testWidgets('EodReturnSheet and MockBackend turn COD cash to 0 once remitted', (tester) async {
    MockBackend().reset();
    final today = MockBackend().selectedDate;

    // Initially not remitted
    expect(MockBackend().isCodRemittedForDate(today), isFalse);

    // Simulate remitCodCash
    await MockBackend().remitCodCash(date: today, amount: 3450.0);
    expect(MockBackend().isCodRemittedForDate(today), isTrue);
    expect(MockBackend().getRemittedCodAmount(today), 3450.0);

    // Pump EOD sheet with delivered parcels
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EodReturnSheet(
            allParcels: deliveredParcels,
            onComplete: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify it turns back into 0
    expect(find.text('₱0.00', skipOffstage: false), findsWidgets);
    expect(find.text('COD CASH REMITTED TODAY', skipOffstage: false), findsOneWidget);
  });
}
