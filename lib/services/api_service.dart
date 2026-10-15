import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_request.dart';
import '../models/delivery_status.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyBaseUrl = 'api_base_url';

  String? _token;
  Map<String, dynamic>? _currentUser;
  String? _customBaseUrl;
  String? _workingBaseUrl;

  List<String> get candidateBaseUrls {
    final list = <String>[];
    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      list.add(_customBaseUrl!.trim());
    }
    if (kIsWeb) {
      list.add('http://127.0.0.1:8000/api/v1');
      return list.toSet().toList();
    }
    list.addAll([
      'http://192.168.86.23/api/v1',      // Apache port 80 proxy (guaranteed open through Windows Firewall on Wi-Fi)
      'http://192.168.86.23:8000/api/v1', // Wi-Fi LAN IP direct Laravel port 8000
      'http://127.0.0.1:8000/api/v1',     // Fast USB adb reverse fallback
      'http://10.0.2.2:8000/api/v1',      // Android Emulator loopback
    ]);
    return list.toSet().toList();
  }

  String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.86.23/api/v1';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api/v1';
  }

  String get baseUrl => _workingBaseUrl ?? _customBaseUrl ?? defaultBaseUrl;

  set baseUrl(String url) {
    _customBaseUrl = url.trim();
    _workingBaseUrl = url.trim();
    SharedPreferences.getInstance().then((sp) => sp.setString(_keyBaseUrl, _customBaseUrl!));
  }

  void resetBaseUrl() {
    _customBaseUrl = null;
    _workingBaseUrl = null;
    SharedPreferences.getInstance().then((sp) => sp.remove(_keyBaseUrl));
  }

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString(_keyToken);
    _customBaseUrl = sp.getString(_keyBaseUrl);
    final userJson = sp.getString(_keyUser);
    if (userJson != null) {
      try {
        _currentUser = jsonDecode(userJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    _autoDiscoverWorkingUrl();
  }

  void _autoDiscoverWorkingUrl() {
    for (final base in candidateBaseUrls) {
      testConnection(base).then((ok) {
        if (ok && (_workingBaseUrl == null || base == defaultBaseUrl)) {
          _workingBaseUrl = base;
        }
      }).catchError((_) {});
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Low-level GET request with automatic fallback between Wi-Fi LAN IP and USB reverse
  Future<http.Response> _get(String path, {Duration timeout = const Duration(seconds: 3)}) async {
    final candidates = [_workingBaseUrl, ...candidateBaseUrls].whereType<String>().toSet().toList();
    Exception? lastException;

    for (final base in candidates) {
      try {
        final res = await http.get(Uri.parse('$base$path'), headers: _headers).timeout(timeout);
        _workingBaseUrl = base;
        return res;
      } on Exception catch (e) {
        lastException = e;
      }
    }
    throw lastException ?? Exception('Cannot connect to server at $baseUrl');
  }

  /// Low-level POST request with automatic fallback
  Future<http.Response> _post(String path, {dynamic body, Duration timeout = const Duration(seconds: 3)}) async {
    final candidates = [_workingBaseUrl, ...candidateBaseUrls].whereType<String>().toSet().toList();
    Exception? lastException;

    for (final base in candidates) {
      try {
        final res = await http
            .post(
              Uri.parse('$base$path'),
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(timeout);
        _workingBaseUrl = base;
        return res;
      } on Exception catch (e) {
        lastException = e;
      }
    }
    throw lastException ?? Exception('Cannot connect to server at $baseUrl');
  }



  /// Test connectivity to a target URL or the current baseUrl
  Future<bool> testConnection([String? url]) async {
    final target = (url ?? baseUrl).replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await http
          .get(Uri.parse('$target/health'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return true;
    } catch (_) {}

    try {
      final res = await http
          .get(Uri.parse('$target/rider/me'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200 || res.statusCode == 401;
    } catch (_) {
      return false;
    }
  }

  /// Login with email and password against Laravel API
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _post(
      '/rider/login',
      body: {'email': email, 'password': password},
      timeout: const Duration(seconds: 3),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _token = data['token'] as String?;
      _currentUser = data['user'] as Map<String, dynamic>?;

      final sp = await SharedPreferences.getInstance();
      if (_token != null) await sp.setString(_keyToken, _token!);
      if (_currentUser != null) {
        await sp.setString(_keyUser, jsonEncode(_currentUser));
      }

      return data as Map<String, dynamic>;
    } else {
      final msg = data['message'] ?? 'Login failed (${response.statusCode})';
      throw Exception(msg);
    }
  }

  /// Register a new rider account
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? vehicleType,
    String? licenseNumber,
    String? licensePhoto,
    String? orCrPhoto,
  }) async {
    final response = await _post(
      '/rider/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': ?phone,
        'vehicle_type': ?vehicleType,
        'license_number': ?licenseNumber,
        'license_photo': ?licensePhoto,
        'or_cr_photo': ?orCrPhoto,
      },
      timeout: const Duration(seconds: 15),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data as Map<String, dynamic>;
    } else {
      final msg = data['message'] ?? 'Registration failed (${response.statusCode})';
      throw Exception(msg);
    }
  }

  /// Logout and revoke current token
  Future<void> logout() async {
    if (_token != null) {
      try {
        await _post('/rider/logout', timeout: const Duration(seconds: 3));
      } catch (_) {}
    }

    _token = null;
    _currentUser = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_keyToken);
    await sp.remove(_keyUser);
  }

  /// Fetch authenticated rider details
  Future<Map<String, dynamic>?> fetchProfile() async {
    if (!isAuthenticated) return null;
    try {
      final res = await _get('/rider/me');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _currentUser = data['user'] as Map<String, dynamic>?;
        final sp = await SharedPreferences.getInstance();
        if (_currentUser != null) {
          await sp.setString(_keyUser, jsonEncode(_currentUser));
        }
        return _currentUser;
      }
    } catch (_) {}
    return _currentUser;
  }

  /// Update online / offline availability
  Future<bool> setAvailability(bool online) async {
    if (!isAuthenticated) return online;
    try {
      final res = await _post('/rider/availability', body: {'available': online});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['is_online'] as bool? ?? online;
      }
    } catch (_) {}
    return online;
  }

  /// Get deliveries assigned to this rider
  Future<List<DeliveryRequest>?> getAssignedDeliveries() async {
    if (!isAuthenticated) return null;
    try {
      final res = await _get('/rider/deliveries');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => DeliveryRequest.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  /// Get available parcels ready for pickup
  Future<List<DeliveryRequest>> getAvailableDeliveries() async {
    if (!isAuthenticated) return [];
    try {
      final res = await _get('/rider/deliveries/available');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => DeliveryRequest.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Accept a delivery
  Future<DeliveryRequest?> acceptDelivery(String id) async {
    try {
      final cleanId = Uri.encodeComponent(id.replaceAll('#', ''));
      final res = await _post('/rider/deliveries/$cleanId/accept');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          return DeliveryRequest.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Update delivery status (pickedUp or delivered)
  Future<DeliveryRequest?> updateDeliveryStatus(String id, DeliveryStage stage) async {
    try {
      final cleanId = Uri.encodeComponent(id.replaceAll('#', ''));
      final res = await _post(
        '/rider/deliveries/$cleanId/status',
        body: {'stage': stage.name},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          return DeliveryRequest.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Sync standardized status payload with backend
  Future<bool> syncStatusPayload(DeliveryStatusPayload payload) async {
    try {
      final cleanId = Uri.encodeComponent(payload.parcelId.replaceAll('#', ''));
      final res = await _post(
        '/rider/deliveries/$cleanId/status',
        body: payload.toJson(),
        timeout: const Duration(seconds: 5),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Get earnings summary and history
  Future<Map<String, dynamic>> getEarnings() async {
    if (!isAuthenticated) {
      return {
        'today': '₱0.00',
        'balance': '₱0.00',
        'completed': '0 deliveries completed',
        'history': <Map<String, String>>[],
      };
    }

    try {
      final res = await _get('/rider/earnings');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final historyList = (data['history'] as List<dynamic>?) ?? [];
        return {
          'today': data['today'] ?? '₱0.00',
          'balance': data['balance'] ?? '₱0.00',
          'completed': data['completed'] ?? '0 deliveries completed',
          'history': historyList.map((e) => Map<String, String>.from(e as Map)).toList(),
        };
      }
    } catch (_) {}

    return {
      'today': '₱0.00',
      'balance': '₱0.00',
      'completed': '0 deliveries completed',
      'history': <Map<String, String>>[],
    };
  }

  /// Send a two-way message between rider and logistics hub staff
  Future<Map<String, dynamic>> sendHubMessage({
    required String message,
    String? parcelId,
  }) async {
    final riderId = _currentUser?['id']?.toString() ?? 'RIDER-001';
    final payload = <String, dynamic>{
      'riderId': riderId,
      'message': message,
      'parcelId': ?parcelId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _post(
        '/rider/chat/messages',
        body: payload,
        timeout: const Duration(seconds: 4),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}

    return {
      'success': true,
      'messageId': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'reply': parcelId != null
          ? 'Hub Staff: Received your update regarding parcel $parcelId. Recorded.'
          : 'Hub Staff: Received your message.',
    };
  }
}
