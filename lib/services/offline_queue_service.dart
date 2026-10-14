import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_status.dart';
import 'api_service.dart';

class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const String _keyQueue = 'offline_status_queue';

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  bool _isFlushing = false;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_keyQueue) ?? [];
    pendingCount.value = raw.length;
    // Attempt to flush on startup
    flushQueue();
  }

  Future<List<DeliveryStatusPayload>> getQueuedUpdates() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_keyQueue) ?? [];
    final list = <DeliveryStatusPayload>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        list.add(DeliveryStatusPayload.fromJson(map));
      } catch (_) {}
    }
    return list;
  }

  Future<void> enqueueStatusUpdate(DeliveryStatusPayload payload) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_keyQueue) ?? [];
    raw.add(jsonEncode(payload.toJson()));
    await sp.setStringList(_keyQueue, raw);
    pendingCount.value = raw.length;

    // Attempt to send immediately
    flushQueue();
  }

  Future<void> flushQueue() async {
    if (_isFlushing || !ApiService.instance.isAuthenticated) return;
    _isFlushing = true;

    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getStringList(_keyQueue) ?? [];
      if (raw.isEmpty) {
        _isFlushing = false;
        return;
      }

      final remaining = <String>[];

      for (final item in raw) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          final payload = DeliveryStatusPayload.fromJson(map);

          final success = await ApiService.instance.syncStatusPayload(payload);
          if (!success) {
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
        }
      }

      await sp.setStringList(_keyQueue, remaining);
      pendingCount.value = remaining.length;
    } finally {
      _isFlushing = false;
    }
  }
}

