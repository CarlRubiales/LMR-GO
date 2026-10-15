import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/models/delivery_request.dart';
import 'package:flutter_app/models/delivery_status.dart';
import 'package:flutter_app/screens/deliveries_screen.dart';
import 'package:flutter_app/services/offline_queue_service.dart';
import 'package:flutter_app/widgets/hub_pickup_sheet.dart';
import 'package:flutter_app/widgets/stop_details_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineQueueService.instance.pendingCount.value = 0;
  });

  group('Delivery Status & Payload Model Tests', () {
    test('all 10 ERP statuses map correctly to wire codes and legacy backend', () {
      expect(DeliveryStatus.assignedToRider.code, 'ASSIGNED_TO_RIDER');
      expect(DeliveryStatus.assignedToRider.legacyBackendStatus, 'Pending');

      expect(DeliveryStatus.pickedUpFromHub.code, 'PICKED_UP_FROM_HUB');
      expect(DeliveryStatus.pickedUpFromHub.legacyBackendStatus, 'In Transit');

      expect(DeliveryStatus.outForDelivery.code, 'OUT_FOR_DELIVERY');
      expect(DeliveryStatus.outForDelivery.legacyBackendStatus, 'Out For Delivery');

      expect(DeliveryStatus.arrived.code, 'ARRIVED');
      expect(DeliveryStatus.arrived.legacyBackendStatus, 'Out For Delivery');

      expect(DeliveryStatus.delivered.code, 'DELIVERED');
      expect(DeliveryStatus.delivered.legacyBackendStatus, 'Delivered');

      expect(DeliveryStatus.deliveryFailed.code, 'DELIVERY_FAILED');
      expect(DeliveryStatus.deliveryFailed.legacyBackendStatus, 'Failed');

      expect(DeliveryStatus.rescheduled.code, 'RESCHEDULED');
      expect(DeliveryStatus.rescheduled.legacyBackendStatus, 'Rescheduled');

      expect(DeliveryStatus.returningToHub.code, 'RETURNING_TO_HUB');
      expect(DeliveryStatus.returningToHub.legacyBackendStatus, 'In Transit');

      expect(DeliveryStatus.returnedToHub.code, 'RETURNED_TO_HUB');
      expect(DeliveryStatus.returnedToHub.legacyBackendStatus, 'Returned');

      expect(DeliveryStatus.completed.code, 'COMPLETED');
      expect(DeliveryStatus.completed.legacyBackendStatus, 'Delivered');
    });

    test('parsing legacy and modern wire codes', () {
      expect(DeliveryStatus.fromCode('ASSIGNED_TO_RIDER'), DeliveryStatus.assignedToRider);
      expect(DeliveryStatus.fromCode('Pending'), DeliveryStatus.assignedToRider);
      expect(DeliveryStatus.fromCode('In Transit'), DeliveryStatus.pickedUpFromHub);
      expect(DeliveryStatus.fromCode('Out For Delivery'), DeliveryStatus.outForDelivery);
      expect(DeliveryStatus.fromCode('ARRIVED'), DeliveryStatus.arrived);
      expect(DeliveryStatus.fromCode('DELIVERED'), DeliveryStatus.delivered);
      expect(DeliveryStatus.fromCode('DELIVERY_FAILED'), DeliveryStatus.deliveryFailed);
    });

    test('DeliveryStatusPayload serialization matches required ERP keys', () {
      const payload = DeliveryStatusPayload(
        parcelId: 'LMR-88219',
        riderId: 'RIDER-42',
        status: 'DELIVERED',
        timestamp: '2026-10-14T10:30:00Z',
        latitude: 14.5839,
        longitude: 121.0543,
        failureReason: null,
        proofUrl: 'https://cdn.lumora.com/pod/88219.jpg',
        codAmount: 650.0,
      );

      final json = payload.toJson();
      expect(json['parcelId'], 'LMR-88219');
      expect(json['riderId'], 'RIDER-42');
      expect(json['status'], 'DELIVERED');
      expect(json['timestamp'], '2026-10-14T10:30:00Z');
      expect(json['latitude'], 14.5839);
      expect(json['longitude'], 121.0543);
      expect(json['proofUrl'], 'https://cdn.lumora.com/pod/88219.jpg');
      expect(json['codAmount'], 650.0);

      final restored = DeliveryStatusPayload.fromJson(json);
      expect(restored.parcelId, payload.parcelId);
      expect(restored.riderId, payload.riderId);
      expect(restored.status, payload.status);
      expect(restored.codAmount, payload.codAmount);
    });

    test('DeliveryRequest deserializes live ERP parcel payload with fallbacks', () {
      final erpPayload = {
        'id': '#1001',
        'db_id': 1,
        'parcel_number': '#1001',
        'tracking_code': '#1001',
        'tracking_number': 'LM-TRK-000001',
        'barcode': '',
        'store': 'Lumora Express Hub',
        'pickup': 'Sorting Bin B-03',
        'dropoff': '45 Rizal Ave, Manila',
        'destination_area': 'Area A — Santa Cruz',
        'status': 'rider_received',
        'recipient_name': 'Juan Dela Cruz',
        'recipient_phone': '09171234567',
        'cod_amount': 350.0,
        'is_cod': true,
        'stop_order': 2,
      };

      final parcel = DeliveryRequest.fromJson(erpPayload);
      expect(parcel.id, '#1001');
      expect(parcel.barcode, '#1001'); // fallback from empty barcode
      expect(parcel.area, 'Area A — Santa Cruz');
      expect(parcel.stage, DeliveryStage.pickedUp); // mapped from rider_received
      expect(parcel.recipientName, 'Juan Dela Cruz');
      expect(parcel.isCod, true);
      expect(parcel.codAmount, 350.0);
      expect(parcel.stopOrder, 2);
    });
  });

  group('Offline Queue Service Tests', () {
    test('enqueuing status update persists payload and increments counter', () async {
      await OfflineQueueService.instance.init();
      expect(OfflineQueueService.instance.pendingCount.value, 0);

      const payload = DeliveryStatusPayload(
        parcelId: 'LMR-88220',
        riderId: 'RIDER-01',
        status: 'OUT_FOR_DELIVERY',
        timestamp: '2026-10-14T11:00:00Z',
        latitude: 14.5800,
        longitude: 121.0500,
      );

      await OfflineQueueService.instance.enqueueStatusUpdate(payload);
      final queued = await OfflineQueueService.instance.getQueuedUpdates();
      expect(queued.length, greaterThanOrEqualTo(1));
      expect(queued.last.parcelId, 'LMR-88220');
    });
  });

  group('Deliveries Tab Widget Tests', () {
    testWidgets('DeliveriesScreen renders tabs and switches between list and map view', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: DeliveriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deliveries'), findsOneWidget);
      expect(find.text('To Load'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);

      // Tap Active tab
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      // Switch to Route Map view
      final mapIcon = find.byTooltip('Route map view');
      expect(mapIcon, findsOneWidget);
      await tester.tap(mapIcon);
      await tester.pumpAndSettle();

      expect(find.text('Lumora Hub'), findsOneWidget);
      expect(find.textContaining('STOPS ROUTED'), findsOneWidget);

      // Switch back to List view
      final listIcon = find.byTooltip('List view');
      await tester.tap(listIcon);
      await tester.pumpAndSettle();
    });

    testWidgets('HubPickupSheet detects unassigned parcel and warns rider', (tester) async {
      const assigned = [
        DeliveryRequest(
          id: 'LMR-88219',
          store: 'Sorting Center',
          pickup: 'Bin A-14',
          dropoff: 'San Juan',
          fee: '₱150',
          distance: '3 km',
          eta: '15m',
          barcode: 'LMR8821901PH',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HubPickupSheet(
              assignedParcels: assigned,
              onRunStarted: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hub Parcel Loading'), findsOneWidget);
      expect(find.text('1 MISSING'), findsOneWidget);

      // Tap on the UNKNOWN-999 simulation chip
      await tester.tap(find.text('UNKNOWN-999'));
      await tester.pumpAndSettle();

      // Should display "Parcel Not Assigned to You!" alert
      expect(find.text('Parcel Not Assigned to You!'), findsOneWidget);
      expect(find.text('Understood · Return to Hub Bin'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Understood · Return to Hub Bin'));
      await tester.pumpAndSettle();
      expect(find.text('Parcel Not Assigned to You!'), findsNothing);
    });

    testWidgets('StopDetailsSheet shows receiver info, actions and Arrived button', (tester) async {
      const parcel = DeliveryRequest(
        id: 'LMR-88219',
        store: 'Sorting Center',
        pickup: 'Bin A-14',
        dropoff: '17 Acacia Ave., San Juan',
        fee: '₱150',
        distance: '3.2 km',
        eta: '15 min',
        recipientName: 'Maria Santos',
        recipientPhone: '+63 917 555 1829',
        isCod: true,
        codAmount: 650.0,
        stopOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StopDetailsSheet(
              parcel: parcel,
              totalStops: 5,
              onStatusChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('+63 917 555 1829'), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Mark Out for Delivery'), findsOneWidget);
      expect(find.text('Message hub about this parcel'), findsOneWidget);
    });
  });
}

