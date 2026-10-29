import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/delivery_request.dart';
import '../models/delivery_status.dart';
import 'api_service.dart';
import 'offline_queue_service.dart';

class MockBackend {
  static final MockBackend _instance = MockBackend._internal();
  factory MockBackend() => _instance;
  MockBackend._internal();

  static final List<DeliveryRequest> _defaultParcels = [
    const DeliveryRequest(
      id: 'LMR-88219',
      store: 'Lumora Sorting Center',
      pickup: 'Hub Sorting Bin A-14',
      dropoff: '17 Acacia Ave., San Juan, Metro Manila',
      fee: '₱150.00',
      distance: '3.2 km',
      eta: '15 min',
      stage: DeliveryStage.accepted,
      recipientName: 'Maria Santos',
      recipientPhone: '+63 917 555 1829',
      area: 'San Juan',
      landmark: 'Near Greenhills Chapel',
      codAmount: 650.00,
      isCod: true,
      stopOrder: 1,
      barcode: 'LMR8821901PH',
    ),
    const DeliveryRequest(
      id: 'LMR-88220',
      store: 'Lumora Sorting Center',
      pickup: 'Hub Sorting Bin A-15',
      dropoff: '302 Sheridan St., Mandaluyong City',
      fee: '₱140.00',
      distance: '4.8 km',
      eta: '22 min',
      stage: DeliveryStage.accepted,
      recipientName: 'Juan Dela Cruz',
      recipientPhone: '+63 918 444 9210',
      area: 'Mandaluyong',
      landmark: 'Corner Reliance St., Gate 2',
      codAmount: 0.0,
      isCod: false,
      stopOrder: 2,
      barcode: 'LMR8822002PH',
    ),
    const DeliveryRequest(
      id: 'LMR-88221',
      store: 'Lumora Sorting Center',
      pickup: 'Hub Sorting Bin B-03',
      dropoff: '45 Emerald Ave., Ortigas Center, Pasig',
      fee: '₱160.00',
      distance: '6.1 km',
      eta: '30 min',
      stage: DeliveryStage.pickedUp,
      recipientName: 'Carlos Mendoza',
      recipientPhone: '+63 920 333 4812',
      area: 'Pasig',
      landmark: 'Taipan Place, 14th Flr Reception',
      codAmount: 1250.00,
      isCod: true,
      stopOrder: 3,
      barcode: 'LMR8822103PH',
    ),
    const DeliveryRequest(
      id: 'LMR-88222',
      store: 'Lumora Sorting Center',
      pickup: 'Hub Sorting Bin B-08',
      dropoff: '88 Boni Ave., Mandaluyong City',
      fee: '₱150.00',
      distance: '2.5 km',
      eta: '12 min',
      stage: DeliveryStage.delivered,
      recipientName: 'Elena Ramos',
      recipientPhone: '+63 922 888 7711',
      area: 'Mandaluyong',
      landmark: 'Beside Boni MRT Stairs',
      codAmount: 420.00,
      isCod: true,
      stopOrder: 4,
      barcode: 'LMR8822204PH',
    ),
    const DeliveryRequest(
      id: 'LMR-88223',
      store: 'Lumora Sorting Center',
      pickup: 'Hub Sorting Bin C-01',
      dropoff: '104 Shaw Blvd., Mandaluyong City',
      fee: '₱150.00',
      distance: '5.2 km',
      eta: '25 min',
      stage: DeliveryStage.failed,
      recipientName: 'Roberto Diaz',
      recipientPhone: '+63 917 222 6633',
      area: 'Mandaluyong',
      landmark: 'Lancaster Hotel Lobby',
      codAmount: 890.00,
      isCod: true,
      stopOrder: 5,
      failureReason: 'Customer Not Home',
      barcode: 'LMR8822305PH',
    ),
  ];

  final List<DeliveryRequest> _runtimeParcels = List<DeliveryRequest>.from(_defaultParcels);
  final ValueNotifier<List<DeliveryRequest>> parcelsNotifier =
      ValueNotifier<List<DeliveryRequest>>(List<DeliveryRequest>.unmodifiable(_defaultParcels));

  Timer? _autoSyncTimer;

  void startAutoSync({Duration interval = const Duration(seconds: 4)}) {
    if (!ApiService.instance.isAuthenticated) return;
    if (_autoSyncTimer != null && _autoSyncTimer!.isActive) return;
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      if (ApiService.instance.isAuthenticated) {
        await getTodayRunParcels();
        await OfflineQueueService.instance.flushQueue();
      }
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  void reset() {
    _runtimeParcels.clear();
    _runtimeParcels.addAll(_defaultParcels);
    parcelsNotifier.value = List<DeliveryRequest>.unmodifiable(_runtimeParcels);
  }

  static const Map<String, String> _defaultEarnings = {
    'today': '₱1,860.00',
    'balance': '₱8,420.50',
    'completed': '4 deliveries completed',
  };

  static const List<Map<String, String>> _defaultHistory = [
    {
      'store': 'Standard Delivery',
      'id': 'LMR-88210',
      'fee': '₱150.00',
      'date': 'Oct 14, 2026',
    },
    {
      'store': 'Standard Delivery',
      'id': 'LMR-88208',
      'fee': '₱150.00',
      'date': 'Oct 14, 2026',
    },
    {
      'store': 'Standard Delivery',
      'id': 'LMR-88195',
      'fee': '₱160.00',
      'date': 'Oct 13, 2026',
    },
  ];

  /// Get parcels assigned to the rider for Today's Run
  Future<List<DeliveryRequest>> getTodayRunParcels() async {
    if (ApiService.instance.isAuthenticated) {
      try {
        final apiDeliveries = await ApiService.instance.getAssignedDeliveries();
        if (apiDeliveries != null) {
          final updatedList = <DeliveryRequest>[];
          for (int i = 0; i < apiDeliveries.length; i++) {
            final item = apiDeliveries[i];
            final localIdx = _runtimeParcels.indexWhere((p) =>
                p.id == item.id ||
                p.barcode == item.barcode ||
                p.trackingNumber == item.trackingNumber);
            if (localIdx != -1) {
              final local = _runtimeParcels[localIdx];
              updatedList.add(item.copyWith(
                stage: local.stage,
                failureReason: local.failureReason ?? item.failureReason,
                failureNotes: local.failureNotes ?? item.failureNotes,
                podPhotoPath: local.podPhotoPath ?? item.podPhotoPath,
                podSignature: local.podSignature ?? item.podSignature,
                podOtp: local.podOtp ?? item.podOtp,
                stopOrder: item.stopOrder > 0 ? item.stopOrder : i + 1,
              ));
            } else {
              updatedList.add(item.copyWith(
                stopOrder: item.stopOrder > 0 ? item.stopOrder : i + 1,
              ));
            }
          }
          _runtimeParcels.clear();
          _runtimeParcels.addAll(updatedList);
          final readonlyList = List<DeliveryRequest>.unmodifiable(_runtimeParcels);
          parcelsNotifier.value = readonlyList;
          return readonlyList;
        }
      } catch (_) {}
    }
    return List<DeliveryRequest>.unmodifiable(_runtimeParcels);
  }

  /// Backward-compatible alias for getAvailableRequests
  Future<List<DeliveryRequest>> getAvailableRequests() async {
    return getTodayRunParcels();
  }

  /// Update parcel status in runtime state, offline queue, and API
  Future<void> updateParcelStatus(
    String parcelId,
    DeliveryStage newStage, {
    String? failureReason,
    String? failureNotes,
    String? podPhotoPath,
    String? podSignature,
    String? podOtp,
    double? codAmountCollected,
  }) async {
    final idx = _runtimeParcels.indexWhere((p) =>
        p.id == parcelId ||
        p.barcode == parcelId ||
        p.trackingNumber == parcelId ||
        p.id == '#$parcelId' ||
        parcelId == '#${p.id}');
    if (idx != -1) {
      final existing = _runtimeParcels[idx];
      _runtimeParcels[idx] = existing.copyWith(
        stage: newStage,
        failureReason: failureReason ?? existing.failureReason,
        failureNotes: failureNotes ?? existing.failureNotes,
        podPhotoPath: podPhotoPath ?? existing.podPhotoPath,
        podSignature: podSignature ?? existing.podSignature,
        podOtp: podOtp ?? existing.podOtp,
        deliveredAt: (newStage == DeliveryStage.delivered || newStage == DeliveryStage.completed)
            ? DateTime.now()
            : existing.deliveredAt,
      );
      parcelsNotifier.value = List<DeliveryRequest>.unmodifiable(_runtimeParcels);
    }

    final riderId = ApiService.instance.currentUser?['id']?.toString() ?? 'RIDER-01';
    final statusWire = DeliveryStatus.fromStage(newStage).code;
    final payload = DeliveryStatusPayload(
      parcelId: parcelId,
      riderId: riderId,
      status: statusWire,
      timestamp: DateTime.now().toIso8601String(),
      latitude: 14.5839,
      longitude: 121.0543,
      failureReason: failureReason,
      proofUrl: podPhotoPath,
      codAmount: codAmountCollected,
    );

    // Queue for sync/send
    await OfflineQueueService.instance.enqueueStatusUpdate(payload);

    if (ApiService.instance.isAuthenticated) {
      try {
        await ApiService.instance.syncStatusPayload(payload);
        await ApiService.instance.updateDeliveryStatus(parcelId, newStage);
      } catch (_) {}
    }
  }

  /// Bulk transition loaded parcels to OUT_FOR_DELIVERY
  Future<void> startDeliveryRun(List<String> parcelIds) async {
    for (final id in parcelIds) {
      await updateParcelStatus(id, DeliveryStage.outForDelivery);
    }
  }

  /// Scan returned undelivered parcel back into hub
  Future<void> returnParcelToHub(String parcelId, {String? reason}) async {
    await updateParcelStatus(
      parcelId,
      DeliveryStage.returnedToHub,
      failureReason: reason ?? 'Returned to Hub Sorting',
    );
  }

  Future<Map<String, String>> getEarnings() async {
    if (ApiService.instance.isAuthenticated) {
      try {
        final data = await ApiService.instance.getEarnings();
        return {
          'today': (data['today'] as String?) ?? _defaultEarnings['today']!,
          'balance': (data['balance'] as String?) ?? _defaultEarnings['balance']!,
          'completed': (data['completed'] as String?) ?? _defaultEarnings['completed']!,
        };
      } catch (_) {}
    }
    return _defaultEarnings;
  }

  Future<List<Map<String, String>>> getHistory() async {
    if (ApiService.instance.isAuthenticated) {
      try {
        final data = await ApiService.instance.getEarnings();
        final history = data['history'] as List<Map<String, String>>?;
        if (history != null && history.isNotEmpty) {
          return history;
        }
      } catch (_) {}
    }
    return _defaultHistory;
  }

  Future<void> submitRegistration(Map<String, dynamic> payload) async {
    if (payload.containsKey('email') && payload.containsKey('password')) {
      await ApiService.instance.register(
        name: payload['fullName'] ?? payload['name'] ?? 'Rider',
        email: payload['email'] as String,
        password: payload['password'] as String,
        phone: payload['phone'] as String?,
        vehicleType: payload['vehicle'] as String?,
        licenseNumber: payload['license_number'] as String?,
        licensePhoto: payload['license_photo'] as String?,
        orCrPhoto: payload['or_cr_photo'] as String?,
        otp: payload['otp'] as String?,
        hubId: payload['hub_id'] as int?,
      );
    }
  }

  Future<void> acceptRequest(String requestId) async {
    if (ApiService.instance.isAuthenticated) {
      try {
        await ApiService.instance.acceptDelivery(requestId);
      } catch (_) {}
    }
  }

  Future<void> updateDelivery(String requestId, DeliveryStage stage) async {
    await updateParcelStatus(requestId, stage);
  }

  Future<String> sendHubMessage({
    required String message,
    String? parcelId,
  }) async {
    if (ApiService.instance.isAuthenticated) {
      try {
        final res = await ApiService.instance.sendHubMessage(
          message: message,
          parcelId: parcelId,
        );
        if (res['reply'] != null) return res['reply'] as String;
      } catch (_) {}
    }

    if (parcelId != null) {
      if (message.contains("Receiver not answering") || message.contains("not answering")) {
        return "Hub Dispatch: Logged unreachable receiver for $parcelId. Please try calling again after 5 mins, or flag for reschedule.";
      } else if (message.contains("Wrong address") || message.contains("address")) {
        return "Hub Dispatch: Checking customer address notes in ERP for $parcelId. Standby for update.";
      } else if (message.contains("I'm outside") || message.contains("outside")) {
        return "Hub Dispatch: Copy that. Notification dispatched to receiver for $parcelId.";
      }
      return "Hub Dispatch: Acknowledged message regarding parcel $parcelId. Operations logged.";
    }

    if (message.contains("help") || message.contains("Help")) {
      return "Hub Dispatch: Standby, dispatcher is reviewing your route status. How can we assist?";
    }
    return "Hub Staff: Message received. Keep safe on the road!";
  }
}
