import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/delivery_request.dart';
import '../models/delivery_status.dart';
import 'api_service.dart';
import 'offline_queue_service.dart';

class MockBackend {
  static final MockBackend _instance = MockBackend._internal();
  factory MockBackend() => _instance;
  MockBackend._internal() {
    _initDateParcels();
  }

  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  final ValueNotifier<DateTime> selectedDateNotifier =
      ValueNotifier<DateTime>(DateTime.now());

  DateTime get selectedDate => selectedDateNotifier.value;

  bool get isSelectedDateToday {
    final now = DateTime.now();
    final sel = selectedDateNotifier.value;
    return sel.year == now.year && sel.month == now.month && sel.day == now.day;
  }

  void setSelectedDate(DateTime date) {
    selectedDateNotifier.value = DateTime(date.year, date.month, date.day);
    getTodayRunParcels(date: selectedDateNotifier.value);
  }

  void jumpToToday() {
    setSelectedDate(DateTime.now());
  }

  final Map<String, List<DeliveryRequest>> _parcelsByDate = {};
  final Set<String> _codRemittedDates = <String>{};
  final Map<String, double> _remittedCodAmounts = <String, double>{};
  final Map<String, DateTime> _remittedCodTimestamps = <String, DateTime>{};
  final Map<String, String> _remittanceStatuses = <String, String>{}; // awaiting_cashier, remitted, short, over, not_remitted
  final Map<String, double> _remittanceDifferences = <String, double>{};
  final Map<String, String> _remittanceCashiers = <String, String>{};

  bool isCodRemittedForDate(DateTime date) {
    if (hasUnremittedCod(date)) return false;
    final key = dateKey(date);
    return _codRemittedDates.contains(key) || _remittanceStatuses[key] == 'awaiting_cashier' || _remittanceStatuses[key] == 'remitted';
  }

  bool hasUnremittedCod(DateTime date) {
    return getUnremittedCodAmount(date) > 0;
  }

  double getUnremittedCodAmount(DateTime date) {
    final key = dateKey(date);
    final currentList = _parcelsByDate[key] ?? _runtimeParcels;
    return currentList
        .where((p) =>
            (p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed) &&
            p.isCod &&
            !p.isCodRemitted)
        .fold(0.0, (sum, p) => sum + p.codAmount);
  }

  String getRemittanceStatus(DateTime date) {
    if (hasUnremittedCod(date)) {
      return 'not_remitted';
    }
    final key = dateKey(date);
    if (_remittanceStatuses.containsKey(key)) {
      return _remittanceStatuses[key]!;
    }
    if (_codRemittedDates.contains(key)) {
      return 'remitted';
    }
    return 'not_remitted';
  }

  double getRemittanceDifference(DateTime date) {
    final key = dateKey(date);
    return _remittanceDifferences[key] ?? 0.0;
  }

  String? getRemittanceCashier(DateTime date) {
    final key = dateKey(date);
    return _remittanceCashiers[key];
  }

  double getRemittedCodAmount(DateTime date) {
    final key = dateKey(date);
    return _remittedCodAmounts[key] ?? 0.0;
  }

  DateTime? getRemittedCodTimestamp(DateTime date) {
    final key = dateKey(date);
    return _remittedCodTimestamps[key];
  }

  /// Check server for latest cashier confirmation status
  Future<String?> checkServerRemittanceStatus([DateTime? date]) async {
    final targetDate = date ?? selectedDate;
    final key = dateKey(targetDate);
    if (!ApiService.instance.isAuthenticated) return _remittanceStatuses[key];

    try {
      final res = await ApiService.instance.getRemittanceStatus(date: key);
      if (res != null && res['status'] != null) {
        final serverStatus = res['status'] as String;
        _remittanceStatuses[key] = serverStatus;
        if (serverStatus == 'remitted' || serverStatus == 'awaiting_cashier') {
          _codRemittedDates.add(key);
        }
        if (res['difference'] != null) {
          _remittanceDifferences[key] = (res['difference'] as num).toDouble();
        }
        if (res['cashier_name'] != null) {
          _remittanceCashiers[key] = res['cashier_name'].toString();
        }
        if (res['counted_amount'] != null) {
          _remittedCodAmounts[key] = (res['counted_amount'] as num).toDouble();
        } else if (res['declared_amount'] != null) {
          _remittedCodAmounts[key] = (res['declared_amount'] as num).toDouble();
        }
        return serverStatus;
      }
    } catch (_) {}
    return _remittanceStatuses[key];
  }

  /// Remit COD cash collected for a date to the hub cashier (Two-step submission)
  Future<void> remitCodCash({
    DateTime? date,
    double? amount,
    String? hubCashierNote,
    List<String>? parcelIds,
  }) async {
    final targetDate = date ?? selectedDate;
    final key = dateKey(targetDate);
    final currentList = _parcelsByDate[key] ?? _runtimeParcels;

    final unremittedTotal = currentList
        .where((p) =>
            (p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed) &&
            p.isCod &&
            !p.isCodRemitted)
        .fold(0.0, (sum, p) => sum + p.codAmount);

    final remittedAmount = amount ?? unremittedTotal;
    _codRemittedDates.add(key);
    _remittedCodAmounts[key] = remittedAmount;
    _remittedCodTimestamps[key] = DateTime.now();
    _remittanceStatuses[key] = 'awaiting_cashier';

    // Mark all delivered COD parcels for this date as remitted
    for (int i = 0; i < currentList.length; i++) {
      final p = currentList[i];
      if ((p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed) && p.isCod) {
        currentList[i] = p.copyWith(isCodRemitted: true);
      }
    }

    _parcelsByDate[key] = currentList;
    _runtimeParcels.clear();
    _runtimeParcels.addAll(currentList);
    parcelsNotifier.value = List<DeliveryRequest>.unmodifiable(_runtimeParcels);

    if (ApiService.instance.isAuthenticated) {
      try {
        final res = await ApiService.instance.submitRemittance(
          declaredAmount: remittedAmount,
          date: key,
          parcelIds: parcelIds,
          note: hubCashierNote,
          idempotencyKey: 'remit_${key}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (res != null && res['status'] != null) {
          _remittanceStatuses[key] = res['status'] as String;
          if (res['difference'] != null) {
            _remittanceDifferences[key] = (res['difference'] as num).toDouble();
          }
        }
      } catch (_) {}
    }
  }

  void _initDateParcels() {
    _parcelsByDate['2026-10-14'] = [
      const DeliveryRequest(
        id: 'LMR-88210',
        store: 'Lumora Sorting Center',
        pickup: 'Hub Sorting Bin A-02',
        dropoff: '12 Pioneer St., Mandaluyong City',
        fee: '₱150.00',
        distance: '2.8 km',
        eta: '10 min',
        stage: DeliveryStage.delivered,
        recipientName: 'Grace Tan',
        recipientPhone: '+63 917 111 2233',
        area: 'Mandaluyong',
        codAmount: 0.0,
        isCod: false,
        stopOrder: 1,
        barcode: 'LMR8821001PH',
      ),
      const DeliveryRequest(
        id: 'LMR-88208',
        store: 'Lumora Sorting Center',
        pickup: 'Hub Sorting Bin B-05',
        dropoff: '55 Shaw Blvd., Pasig City',
        fee: '₱150.00',
        distance: '3.5 km',
        eta: '15 min',
        stage: DeliveryStage.delivered,
        recipientName: 'David Lee',
        recipientPhone: '+63 918 222 3344',
        area: 'Pasig',
        codAmount: 850.0,
        isCod: true,
        stopOrder: 2,
        barcode: 'LMR8820802PH',
      ),
    ];
  }

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

  final List<DeliveryRequest> _runtimeParcels = <DeliveryRequest>[];
  late final ValueNotifier<List<DeliveryRequest>> parcelsNotifier =
      ValueNotifier<List<DeliveryRequest>>(const <DeliveryRequest>[]);

  Timer? _autoSyncTimer;

  void startAutoSync({Duration interval = const Duration(seconds: 3)}) {
    if (!ApiService.instance.isAuthenticated) return;
    if (_autoSyncTimer != null && _autoSyncTimer!.isActive) return;
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      if (ApiService.instance.isAuthenticated) {
        await getTodayRunParcels();
        await OfflineQueueService.instance.flushQueue();
      } else {
        stopAutoSync();
      }
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  void reset() {
    stopAutoSync();
    selectedDateNotifier.value = DateTime.now();
    _runtimeParcels.clear();
    _parcelsByDate.clear();
    _codRemittedDates.clear();
    _remittedCodAmounts.clear();
    _remittedCodTimestamps.clear();
    _remittanceStatuses.clear();
    _remittanceDifferences.clear();
    _remittanceCashiers.clear();
    parcelsNotifier.value = const <DeliveryRequest>[];
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

  /// Get parcels assigned to the rider for the selected Run (defaults to Today's Run)
  Future<List<DeliveryRequest>> getTodayRunParcels({DateTime? date}) async {
    final targetDate = date ?? selectedDate;
    final key = dateKey(targetDate);

    if (ApiService.instance.isAuthenticated) {
      try {
        final apiDeliveries = await ApiService.instance.getAssignedDeliveries(date: key);
        if (apiDeliveries != null) {
          final updatedList = <DeliveryRequest>[];
          final existingLocal = _parcelsByDate[key] ?? <DeliveryRequest>[];

          for (int i = 0; i < apiDeliveries.length; i++) {
            final item = apiDeliveries[i];
            final localIdx = existingLocal.indexWhere((p) =>
                p.id == item.id ||
                p.barcode == item.barcode ||
                p.trackingNumber == item.trackingNumber);
            if (localIdx != -1) {
              final local = existingLocal[localIdx];
              updatedList.add(item.copyWith(
                stage: item.stage,
                isCodRemitted: item.isCodRemitted || local.isCodRemitted,
                failureReason: item.failureReason ?? local.failureReason,
                failureNotes: item.failureNotes ?? local.failureNotes,
                returnReason: item.returnReason ?? local.returnReason,
                returnDetails: item.returnDetails ?? local.returnDetails,
                sellerNote: item.sellerNote ?? local.sellerNote,
                returnStatus: item.returnStatus ?? local.returnStatus,
                returnItems: item.returnItems ?? local.returnItems,
                returnEvidence: item.returnEvidence ?? local.returnEvidence,
                isReturnRefund: item.isReturnRefund || local.isReturnRefund,
                podPhotoPath: local.podPhotoPath ?? item.podPhotoPath,
                podVideoPath: local.podVideoPath ?? item.podVideoPath,
                podSignature: local.podSignature ?? item.podSignature,
                podOtp: local.podOtp ?? item.podOtp,
                stopOrder: item.stopOrder > 0
                    ? item.stopOrder
                    : (local.stopOrder > 0 ? local.stopOrder : i + 1),
              ));
            } else {
              updatedList.add(item.copyWith(
                stopOrder: item.stopOrder > 0 ? item.stopOrder : i + 1,
              ));
            }
          }
          _parcelsByDate[key] = updatedList;
          _runtimeParcels.clear();
          _runtimeParcels.addAll(updatedList);
          final readonlyList = List<DeliveryRequest>.unmodifiable(_runtimeParcels);
          parcelsNotifier.value = readonlyList;
          return readonlyList;
        }
      } catch (_) {}
    }

    if (!_parcelsByDate.containsKey(key)) {
      _parcelsByDate[key] = <DeliveryRequest>[];
    }

    final localList = _parcelsByDate[key] ?? [];
    _runtimeParcels.clear();
    _runtimeParcels.addAll(localList);
    final readonlyList = List<DeliveryRequest>.unmodifiable(_runtimeParcels);
    parcelsNotifier.value = readonlyList;
    return readonlyList;
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
    String? podVideoPath,
    String? podSignature,
    String? podOtp,
    double? codAmountCollected,
  }) async {
    final key = dateKey(selectedDate);
    final currentList = _parcelsByDate[key] ?? _runtimeParcels;
    final idx = currentList.indexWhere((p) =>
        p.id == parcelId ||
        p.barcode == parcelId ||
        p.trackingNumber == parcelId ||
        p.id == '#$parcelId' ||
        parcelId == '#${p.id}');
    if (idx != -1) {
      final existing = currentList[idx];
      final updated = existing.copyWith(
        stage: newStage,
        failureReason: failureReason ?? existing.failureReason,
        failureNotes: failureNotes ?? existing.failureNotes,
        returnReason: failureReason ?? existing.returnReason,
        returnDetails: failureNotes ?? existing.returnDetails,
        isReturnRefund: newStage == DeliveryStage.returnedToHub || existing.isReturnRefund,
        podPhotoPath: podPhotoPath ?? existing.podPhotoPath,
        podVideoPath: podVideoPath ?? existing.podVideoPath,
        podSignature: podSignature ?? existing.podSignature,
        podOtp: podOtp ?? existing.podOtp,
        deliveredAt: (newStage == DeliveryStage.delivered || newStage == DeliveryStage.completed)
            ? DateTime.now()
            : existing.deliveredAt,
      );
      currentList[idx] = updated;
      _parcelsByDate[key] = currentList;
      _runtimeParcels.clear();
      _runtimeParcels.addAll(currentList);
      parcelsNotifier.value = List<DeliveryRequest>.unmodifiable(_runtimeParcels);
    }

    String? photoBase64;
    if (!kIsWeb && podPhotoPath != null && podPhotoPath.isNotEmpty && !podPhotoPath.startsWith('http')) {
      try {
        final photoFile = File(podPhotoPath);
        if (await photoFile.exists()) {
          final bytes = await photoFile.readAsBytes();
          final ext = podPhotoPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
          photoBase64 = 'data:image/$ext;base64,${base64Encode(bytes)}';
        }
      } catch (_) {}
    }

    String? videoBase64;
    if (!kIsWeb && podVideoPath != null && podVideoPath.isNotEmpty && !podVideoPath.startsWith('http')) {
      try {
        final videoFile = File(podVideoPath);
        if (await videoFile.exists()) {
          final bytes = await videoFile.readAsBytes();
          // Cap inline base64 at 18MB so JSON payloads stay within HTTP limits
          if (bytes.length <= 18 * 1024 * 1024) {
            videoBase64 = 'data:video/mp4;base64,${base64Encode(bytes)}';
          }
        }
      } catch (_) {}
    }

    final riderId = ApiService.instance.currentUser?['id']?.toString() ?? 'RIDER-01';
    final statusWire = DeliveryStatus.fromStage(newStage).code;
    final isReturnRefund = newStage == DeliveryStage.failed ||
        newStage == DeliveryStage.returningToHub ||
        newStage == DeliveryStage.returnedToHub;

    final payload = DeliveryStatusPayload(
      parcelId: parcelId,
      riderId: riderId,
      status: statusWire,
      timestamp: DateTime.now().toIso8601String(),
      latitude: 14.5839,
      longitude: 121.0543,
      failureReason: failureReason,
      failureNotes: failureNotes,
      proofUrl: podPhotoPath,
      proofVideoUrl: podVideoPath,
      proofPhotoBase64: photoBase64,
      proofVideoBase64: videoBase64,
      isReturnRefund: isReturnRefund ? true : null,
      codAmount: codAmountCollected,
    );

    // Queue for sync/send
    await OfflineQueueService.instance.enqueueStatusUpdate(payload);

    if (ApiService.instance.isAuthenticated) {
      try {
        final synced = await ApiService.instance.syncStatusPayload(payload);
        if (!synced) {
          await ApiService.instance.updateDeliveryStatus(parcelId, newStage);
        }
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

  Future<Map<String, String>> getEarnings({DateTime? date}) async {
    final targetDate = date ?? selectedDate;
    final key = dateKey(targetDate);
    final nowKey = dateKey(DateTime.now());

    if (ApiService.instance.isAuthenticated) {
      try {
        final data = await ApiService.instance.getEarnings();
        if (key == nowKey) {
          return {
            'today': (data['today'] as String?) ?? '₱0.00',
            'balance': (data['balance'] as String?) ?? '₱0.00',
            'completed': (data['completed'] as String?) ?? '0 deliveries completed',
          };
        }
      } catch (_) {}
    }

    // Calculation for selected date
    final parcelsForDate = _parcelsByDate[key] ?? [];
    final completed = parcelsForDate
        .where((p) => p.stage == DeliveryStage.delivered || p.stage == DeliveryStage.completed)
        .length;
    // Base commission rate for rider is ₱20.00 per delivered parcel
    final earned = completed * 20.0;
    return {
      'today': '₱${earned.toStringAsFixed(2)}',
      'balance': '₱${earned.toStringAsFixed(2)}',
      'completed': '$completed deliveries completed',
    };
  }

  Future<List<Map<String, String>>> getHistory() async {
    if (ApiService.instance.isAuthenticated) {
      try {
        final data = await ApiService.instance.getEarnings();
        final history = data['history'] as List<Map<String, String>>?;
        if (history != null) {
          return history;
        }
      } catch (_) {}
      return const [];
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
        province: payload['province'] as String?,
        municipality: payload['municipality'] as String?,
        barangay: payload['barangay'] as String?,
        street: payload['street'] as String?,
        birthday: payload['birthday'] as String?,
        birthDate: payload['birth_date'] as String?,
        dateOfBirth: (payload['date_of_birth'] ?? payload['birthday'] ?? payload['birth_date']) as String?,
        age: payload['age']?.toString(),
        sex: payload['sex'] as String?,
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
