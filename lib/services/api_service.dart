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
      'http://192.168.86.68/api/v1',          // Wi-Fi Apache port 80 proxy (Firewall approved)
      'http://192.168.86.68:8000/api/v1',     // Wi-Fi direct Laravel port 8000
      'https://logistics.lumora.party/api/v1', // Live Laravel Cloud Logistics Production
      'http://192.168.137.1/api/v1',          // Laptop Mobile Hotspot Apache port 80 proxy
      'http://192.168.137.1:8000/api/v1',     // Laptop Mobile Hotspot direct Laravel port 8000
      'http://127.0.0.1:8000/api/v1',         // Fast USB adb reverse (works 100% when plugged into PC)
      'http://10.0.2.2:8000/api/v1',          // Android Emulator loopback
    ]);
    return list.toSet().toList();
  }

  String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.86.68/api/v1';
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
        if (_currentUser?['email'] != null && _currentUser!['email'].toString().isNotEmpty)
          'X-Rider-Email': _currentUser!['email'].toString(),
        if (_currentUser?['name'] != null && _currentUser!['name'].toString().isNotEmpty)
          'X-Rider-Name': _currentUser!['name'].toString(),
      };

  /// Low-level GET request with automatic fallback between Wi-Fi LAN IP and USB reverse
  Future<http.Response> _get(String path, {Duration timeout = const Duration(seconds: 5)}) async {
    final candidates = [_workingBaseUrl, ...candidateBaseUrls].whereType<String>().toSet().toList();
    Exception? lastException;
    http.Response? lastResponse;

    for (final base in candidates) {
      try {
        final res = await http.get(Uri.parse('$base$path'), headers: _headers).timeout(timeout);
        if (res.statusCode == 401 || res.statusCode >= 500) {
          lastResponse = res;
          continue;
        }
        _workingBaseUrl = base;
        return res;
      } on Exception catch (e) {
        lastException = e;
      }
    }
    if (lastResponse != null) return lastResponse;
    throw lastException ?? Exception('Cannot connect to server at $baseUrl');
  }

  /// Low-level POST request with automatic fallback
  Future<http.Response> _post(String path, {dynamic body, Duration timeout = const Duration(seconds: 5)}) async {
    final candidates = [_workingBaseUrl, ...candidateBaseUrls].whereType<String>().toSet().toList();
    Exception? lastException;
    http.Response? lastResponse;

    for (final base in candidates) {
      try {
        final res = await http
            .post(
              Uri.parse('$base$path'),
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(timeout);
        if (res.statusCode == 401 || res.statusCode >= 500) {
          lastResponse = res;
          continue;
        }
        _workingBaseUrl = base;
        return res;
      } on Exception catch (e) {
        lastException = e;
      }
    }
    if (lastResponse != null) return lastResponse;
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

  /// Login with email and password against Laravel API.
  /// Throws an Exception if credentials are invalid or if the rider account is not yet approved by Logistics.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _post(
      '/rider/login',
      body: {'email': email.trim(), 'password': password},
      timeout: const Duration(seconds: 10),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _token = data['token'] as String?;
      _currentUser = data['user'] as Map<String, dynamic>?;
      if (_currentUser != null) {
        _currentUser!['availability'] = 'online';
      }

      final sp = await SharedPreferences.getInstance();
      if (_token != null) await sp.setString(_keyToken, _token!);
      if (_currentUser != null) {
        await sp.setString(_keyUser, jsonEncode(_currentUser));
      }

      // Ensure live Online availability is synced across both Local & Cloud servers on login
      setAvailability(true);

      return data;
    } else {
      final msg = data['message']?.toString() ?? 'Login failed. Please verify your credentials and approval status.';
      throw Exception(msg);
    }
  }

  /// Request a 6-digit OTP sent to the rider's email
  Future<Map<String, dynamic>> sendOtp(String email, {String? name}) async {
    final response = await _post(
      '/rider/send-otp',
      body: {
        'email': email.trim(),
        'name': ?name?.trim(),
      },
      timeout: const Duration(seconds: 15),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      final msg = data['message'] ?? 'Failed to send OTP (${response.statusCode})';
      throw Exception(msg);
    }
  }

  /// Verify 6-digit email OTP
  Future<bool> verifyOtp(String email, String otp) async {
    final response = await _post(
      '/rider/verify-otp',
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
      },
      timeout: const Duration(seconds: 10),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data['verified'] == true;
    } else {
      final msg = data['message'] ?? 'OTP verification failed (${response.statusCode})';
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
    String? otp,
    int? hubId,
    String? province,
    String? municipality,
    String? barangay,
    String? street,
    String? birthday,
    String? birthDate,
    String? dateOfBirth,
    String? age,
    String? sex,
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
        'otp': ?otp,
        'hub_id': ?hubId,
        'province': ?province,
        'municipality': ?municipality,
        'barangay': ?barangay,
        'street': ?street,
        'birthday': ?birthday,
        'birth_date': ?birthDate,
        'date_of_birth': ?dateOfBirth,
        'age': ?age,
        'sex': ?sex,
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

  /// Fetch active hubs for registration dropdown
  Future<List<Map<String, dynamic>>> getHubs() async {
    final response = await _get('/hubs', timeout: const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = data['hubs'] as List<dynamic>;
      return list.map((h) => Map<String, dynamic>.from(h as Map)).toList();
    }
    throw Exception('Failed to load hubs');
  }

  /// Logout, mark rider offline on all servers, and revoke current token
  Future<void> logout() async {
    final email = _currentUser?['email']?.toString();
    final name = _currentUser?['name']?.toString();
    final headersSnapshot = Map<String, String>.from(_headers);

    _token = null;
    _currentUser = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_keyToken);
    await sp.remove(_keyUser);

    if (email != null && email.isNotEmpty) {
      final payload = jsonEncode({
        'available': false,
        'availability': 'offline',
        'rider_email': email,
        'rider_name': name ?? '',
      });
      for (final target in {baseUrl, 'https://logistics.lumora.party/api/v1'}) {
        try {
          http
              .post(
                Uri.parse('$target/rider/availability'),
                headers: headersSnapshot,
                body: payload,
              )
              .timeout(const Duration(seconds: 4))
              .catchError((_) => http.Response('', 500));
          http
              .post(
                Uri.parse('$target/rider/logout'),
                headers: headersSnapshot,
                body: payload,
              )
              .timeout(const Duration(seconds: 4))
              .catchError((_) => http.Response('', 500));
        } catch (_) {}
      }
    }
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

  /// Update online / offline availability across both active server and Cloud Logistics
  Future<bool> setAvailability(bool online) async {
    if (!isAuthenticated) return online;
    final email = _currentUser?['email']?.toString();
    final name = _currentUser?['name']?.toString();
    final statusStr = online ? 'online' : 'offline';

    if (_currentUser != null) {
      _currentUser!['availability'] = statusStr;
      SharedPreferences.getInstance().then((sp) {
        if (_currentUser != null) {
          sp.setString(_keyUser, jsonEncode(_currentUser));
        }
      });
    }

    final bodyPayload = <String, dynamic>{
      'available': online,
      'availability': statusStr,
      if (email != null && email.isNotEmpty) 'rider_email': email,
      if (name != null && name.isNotEmpty) 'rider_name': name,
    };

    // Also mirror directly to Cloud Logistics so https://logistics.lumora.party/riders updates immediately
    const cloudBase = 'https://logistics.lumora.party/api/v1';
    if (!baseUrl.contains('logistics.lumora.party')) {
      try {
        http
            .post(
              Uri.parse('$cloudBase/rider/availability'),
              headers: _headers,
              body: jsonEncode(bodyPayload),
            )
            .timeout(const Duration(seconds: 4))
            .catchError((_) => http.Response('', 500));
      } catch (_) {}
    }

    try {
      final res = await _post('/rider/availability', body: bodyPayload);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['is_online'] as bool? ?? online;
      }
    } catch (_) {}
    return online;
  }

  /// Get deliveries assigned to this rider for a specific date (defaults to today)
  Future<List<DeliveryRequest>?> getAssignedDeliveries({String? date}) async {
    if (!isAuthenticated) return null;
    try {
      final query = date != null && date.trim().isNotEmpty ? '?date=${date.trim()}' : '';
      final res = await _get('/rider/deliveries$query');
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
      final hasMedia = (payload.proofPhotoBase64 != null && payload.proofPhotoBase64!.isNotEmpty) ||
          (payload.proofVideoBase64 != null && payload.proofVideoBase64!.isNotEmpty);
      final res = await _post(
        '/rider/deliveries/$cleanId/status',
        body: payload.toJson(),
        timeout: Duration(seconds: hasMedia ? 25 : 6),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Submit end-of-day COD remittance to hub cashier (Two-step flow: status -> awaiting_cashier)
  Future<Map<String, dynamic>?> submitRemittance({
    required double declaredAmount,
    String? date,
    List<String>? parcelIds,
    String? note,
    String? idempotencyKey,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final res = await _post(
        '/rider/remit/submit',
        body: {
          'declared_amount': declaredAmount,
          'date': ?date,
          'parcel_ids': ?parcelIds,
          'rider_note': ?note,
          'idempotency_key': ?idempotencyKey,
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get status of COD remittance for a specific date
  Future<Map<String, dynamic>?> getRemittanceStatus({String? date}) async {
    if (!isAuthenticated) return null;
    try {
      final query = date != null ? '?date=$date' : '';
      final res = await _get('/rider/remit/status$query');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Remit collected COD cash to hub cashier for a date (legacy endpoint)
  Future<Map<String, dynamic>?> remitCodCash({
    required double amount,
    String? date,
    String? note,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final res = await _post(
        '/rider/remit-cod',
        body: {
          'amount': amount,
          'date': ?date,
          'note': ?note,
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
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

  Map<String, dynamic>? _hubChatInfo;
  int _unreadHubMessages = 0;

  Map<String, dynamic>? get hubChatInfo => _hubChatInfo;
  int get unreadHubMessages => _unreadHubMessages;

  /// Fetch live real-time messages between rider and logistics hub
  Future<List<Map<String, dynamic>>> fetchMessages({
    String? parcelId,
    bool markRead = true,
  }) async {
    if (!isAuthenticated) return [];
    try {
      final params = <String, String>{
        'mark_read': markRead ? '1' : '0',
        if (parcelId != null && parcelId.isNotEmpty) 'parcel_id': parcelId,
      };
      final queryString = params.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final endpoint = '/rider/messages?$queryString';
      final res = await _get(endpoint, timeout: const Duration(seconds: 4));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data['hub'] is Map) {
            _hubChatInfo = Map<String, dynamic>.from(data['hub'] as Map);
          }
          if (data['unread_count'] != null) {
            _unreadHubMessages = int.tryParse(data['unread_count'].toString()) ?? 0;
          } else if (markRead) {
            _unreadHubMessages = 0;
          }
          if (data['data'] is List) {
            return List<Map<String, dynamic>>.from(
              (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        }
      }
    } catch (_) {}
    return [];
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
      'text': message,
      ...?parcelId != null ? {'parcel_id': parcelId} : null,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _post(
        '/rider/messages',
        body: payload,
        timeout: const Duration(seconds: 4),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data['hub'] is Map) {
            _hubChatInfo = Map<String, dynamic>.from(data['hub'] as Map);
          }
          return data;
        }
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
