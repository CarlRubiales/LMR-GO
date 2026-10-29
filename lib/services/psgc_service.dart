import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a Philippine location (Province/Area, City/Municipality, Barangay)
class PsgcLocation {
  final String code;
  final String name;
  final String? type;

  const PsgcLocation({
    required this.code,
    required this.name,
    this.type,
  });

  factory PsgcLocation.fromJson(Map<String, dynamic> json, {String? type}) {
    return PsgcLocation(
      code: json['code']?.toString() ?? '',
      name: cleanName(json['name']?.toString() ?? ''),
      type: type ?? json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    if (type != null) 'type': type,
  };

  /// Fixes potential character encoding issues in names (e.g. "Los BaÃ±os" -> "Los Baños")
  static String cleanName(String raw) {
    return raw
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã', 'Ñ')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã‰', 'É')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ã', 'Ó')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã', 'Á')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã', 'Í')
        .trim();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PsgcLocation &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => code.hashCode ^ name.hashCode;

  @override
  String toString() => name;
}

/// Service providing access to the Philippine Standard Geographic Code (PSGC)
/// with multi-tier caching (Memory -> SharedPreferences -> Embedded Fallback).
class PsgcService {
  PsgcService._internal();
  static final PsgcService instance = PsgcService._internal();

  static const String _baseUrl = 'https://psgc.gitlab.io/api';
  final Map<String, List<PsgcLocation>> _memoryCache = {};

  /// Pre-seeded official list of all 81 Philippine provinces + Metro Manila (NCR)
  static final List<PsgcLocation> initialProvinces = _allProvincesRaw.map((p) => PsgcLocation(
    code: p['code']!,
    name: p['name']!,
    type: 'province',
  )).toList();

  /// Get all provinces & administrative areas (instant via embedded PSGC, refreshed from API if needed)
  Future<List<PsgcLocation>> getProvinces() async {
    const cacheKey = 'psgc_provinces_all';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // Check SharedPreferences
    final cached = await _loadFromStorage(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _memoryCache[cacheKey] = cached;
      return cached;
    }

    // Try fetching from API in background or fallback to full embedded list
    try {
      final response = await http.get(Uri.parse('$_baseUrl/provinces.json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = <PsgcLocation>[
          const PsgcLocation(code: '130000000', name: 'Metro Manila (NCR)', type: 'region'),
        ];
        list.addAll(data.map((item) => PsgcLocation.fromJson(item as Map<String, dynamic>, type: 'province')));
        list.sort((a, b) => a.name.compareTo(b.name));

        _memoryCache[cacheKey] = list;
        _saveToStorage(cacheKey, list);
        return list;
      }
    } catch (e) {
      debugPrint('PSGC: Network error fetching provinces, using embedded list: $e');
    }

    _memoryCache[cacheKey] = initialProvinces;
    return initialProvinces;
  }

  /// Get cities and municipalities for a chosen province or administrative area
  Future<List<PsgcLocation>> getCitiesMunicipalities(PsgcLocation province) async {
    final cacheKey = 'psgc_cities_${province.code}';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    final cached = await _loadFromStorage(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _memoryCache[cacheKey] = cached;
      return cached;
    }

    // Metro Manila uses region endpoint
    final url = province.code == '130000000'
        ? '$_baseUrl/regions/130000000/cities-municipalities.json'
        : '$_baseUrl/provinces/${province.code}/cities-municipalities.json';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = data
            .map((item) => PsgcLocation.fromJson(item as Map<String, dynamic>, type: 'city_municipality'))
            .toList();
        list.sort((a, b) => a.name.compareTo(b.name));

        _memoryCache[cacheKey] = list;
        _saveToStorage(cacheKey, list);
        return list;
      }
    } catch (e) {
      debugPrint('PSGC: Network error fetching cities for ${province.name}: $e');
    }

    // Fallback seed data if offline or network fails
    final fallback = _getFallbackCities(province.code);
    if (fallback.isNotEmpty) {
      _memoryCache[cacheKey] = fallback;
      return fallback;
    }

    throw Exception('Could not load cities for ${province.name}. Please check your connection and tap to retry.');
  }

  /// Get barangays for a chosen city or municipality
  Future<List<PsgcLocation>> getBarangays(PsgcLocation cityMunicipality) async {
    final cacheKey = 'psgc_brgys_${cityMunicipality.code}';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    final cached = await _loadFromStorage(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _memoryCache[cacheKey] = cached;
      return cached;
    }

    final url = '$_baseUrl/cities-municipalities/${cityMunicipality.code}/barangays.json';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = data
            .map((item) => PsgcLocation.fromJson(item as Map<String, dynamic>, type: 'barangay'))
            .toList();
        list.sort((a, b) => a.name.compareTo(b.name));

        _memoryCache[cacheKey] = list;
        _saveToStorage(cacheKey, list);
        return list;
      }
    } catch (e) {
      debugPrint('PSGC: Network error fetching barangays for ${cityMunicipality.name}: $e');
    }

    // Fallback seed data if offline or network fails
    final fallback = _getFallbackBarangays(cityMunicipality.code);
    if (fallback.isNotEmpty) {
      _memoryCache[cacheKey] = fallback;
      return fallback;
    }

    throw Exception('Could not load barangays for ${cityMunicipality.name}. Please check your connection and tap to retry.');
  }

  // Persistent storage helpers
  Future<List<PsgcLocation>?> _loadFromStorage(String key) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => PsgcLocation.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveToStorage(String key, List<PsgcLocation> list) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = jsonEncode(list.map((e) => e.toJson()).toList());
      await sp.setString(key, raw);
    } catch (_) {}
  }

  // Embedded seed datasets for offline resilience
  static const List<Map<String, String>> _allProvincesRaw = [
    {"code": "140100000", "name": "Abra"},
    {"code": "160200000", "name": "Agusan Del Norte"},
    {"code": "160300000", "name": "Agusan Del Sur"},
    {"code": "060400000", "name": "Aklan"},
    {"code": "050500000", "name": "Albay"},
    {"code": "060600000", "name": "Antique"},
    {"code": "148100000", "name": "Apayao"},
    {"code": "037700000", "name": "Aurora"},
    {"code": "150700000", "name": "Basilan"},
    {"code": "030800000", "name": "Bataan"},
    {"code": "020900000", "name": "Batanes"},
    {"code": "041000000", "name": "Batangas"},
    {"code": "141100000", "name": "Benguet"},
    {"code": "087800000", "name": "Biliran"},
    {"code": "071200000", "name": "Bohol"},
    {"code": "101300000", "name": "Bukidnon"},
    {"code": "031400000", "name": "Bulacan"},
    {"code": "021500000", "name": "Cagayan"},
    {"code": "051600000", "name": "Camarines Norte"},
    {"code": "051700000", "name": "Camarines Sur"},
    {"code": "101800000", "name": "Camiguin"},
    {"code": "061900000", "name": "Capiz"},
    {"code": "052000000", "name": "Catanduanes"},
    {"code": "042100000", "name": "Cavite"},
    {"code": "072200000", "name": "Cebu"},
    {"code": "124700000", "name": "Cotabato"},
    {"code": "118200000", "name": "Davao De Oro"},
    {"code": "112300000", "name": "Davao Del Norte"},
    {"code": "112400000", "name": "Davao Del Sur"},
    {"code": "118600000", "name": "Davao Occidental"},
    {"code": "112500000", "name": "Davao Oriental"},
    {"code": "168500000", "name": "Dinagat Islands"},
    {"code": "082600000", "name": "Eastern Samar"},
    {"code": "067900000", "name": "Guimaras"},
    {"code": "142700000", "name": "Ifugao"},
    {"code": "012800000", "name": "Ilocos Norte"},
    {"code": "012900000", "name": "Ilocos Sur"},
    {"code": "063000000", "name": "Iloilo"},
    {"code": "023100000", "name": "Isabela"},
    {"code": "143200000", "name": "Kalinga"},
    {"code": "013300000", "name": "La Union"},
    {"code": "043400000", "name": "Laguna"},
    {"code": "103500000", "name": "Lanao Del Norte"},
    {"code": "153600000", "name": "Lanao Del Sur"},
    {"code": "083700000", "name": "Leyte"},
    {"code": "153800000", "name": "Maguindanao"},
    {"code": "174000000", "name": "Marinduque"},
    {"code": "054100000", "name": "Masbate"},
    {"code": "130000000", "name": "Metro Manila (NCR)"},
    {"code": "104200000", "name": "Misamis Occidental"},
    {"code": "104300000", "name": "Misamis Oriental"},
    {"code": "144400000", "name": "Mountain Province"},
    {"code": "064500000", "name": "Negros Occidental"},
    {"code": "074600000", "name": "Negros Oriental"},
    {"code": "084800000", "name": "Northern Samar"},
    {"code": "034900000", "name": "Nueva Ecija"},
    {"code": "025000000", "name": "Nueva Vizcaya"},
    {"code": "175100000", "name": "Occidental Mindoro"},
    {"code": "175200000", "name": "Oriental Mindoro"},
    {"code": "175300000", "name": "Palawan"},
    {"code": "035400000", "name": "Pampanga"},
    {"code": "015500000", "name": "Pangasinan"},
    {"code": "045600000", "name": "Quezon"},
    {"code": "025700000", "name": "Quirino"},
    {"code": "045800000", "name": "Rizal"},
    {"code": "175900000", "name": "Romblon"},
    {"code": "086000000", "name": "Samar"},
    {"code": "128000000", "name": "Sarangani"},
    {"code": "076100000", "name": "Siquijor"},
    {"code": "056200000", "name": "Sorsogon"},
    {"code": "126300000", "name": "South Cotabato"},
    {"code": "086400000", "name": "Southern Leyte"},
    {"code": "126500000", "name": "Sultan Kudarat"},
    {"code": "156600000", "name": "Sulu"},
    {"code": "166700000", "name": "Surigao Del Norte"},
    {"code": "166800000", "name": "Surigao Del Sur"},
    {"code": "036900000", "name": "Tarlac"},
    {"code": "157000000", "name": "Tawi-Tawi"},
    {"code": "037100000", "name": "Zambales"},
    {"code": "097200000", "name": "Zamboanga Del Norte"},
    {"code": "097300000", "name": "Zamboanga Del Sur"},
    {"code": "098300000", "name": "Zamboanga Sibugay"}
  ];

  static List<PsgcLocation> _getFallbackCities(String provinceCode) {
    if (provinceCode == '043400000') {
      // Laguna cities & municipalities
      return [
        const PsgcLocation(code: '043401000', name: 'Alaminos'),
        const PsgcLocation(code: '043402000', name: 'Bay'),
        const PsgcLocation(code: '043403000', name: 'City of Biñan'),
        const PsgcLocation(code: '043404000', name: 'City of Cabuyao'),
        const PsgcLocation(code: '043405000', name: 'City of Calamba'),
        const PsgcLocation(code: '043406000', name: 'Calauan'),
        const PsgcLocation(code: '043407000', name: 'Cavinti'),
        const PsgcLocation(code: '043408000', name: 'Famy'),
        const PsgcLocation(code: '043409000', name: 'Kalayaan'),
        const PsgcLocation(code: '043410000', name: 'Liliw'),
        const PsgcLocation(code: '043411000', name: 'Los Baños'),
        const PsgcLocation(code: '043412000', name: 'Luisiana'),
        const PsgcLocation(code: '043413000', name: 'Lumban'),
        const PsgcLocation(code: '043414000', name: 'Mabitac'),
        const PsgcLocation(code: '043415000', name: 'Magdalena'),
        const PsgcLocation(code: '043416000', name: 'Majayjay'),
        const PsgcLocation(code: '043417000', name: 'Nagcarlan'),
        const PsgcLocation(code: '043418000', name: 'Paete'),
        const PsgcLocation(code: '043419000', name: 'Pagsanjan'),
        const PsgcLocation(code: '043420000', name: 'Pakil'),
        const PsgcLocation(code: '043421000', name: 'Pangil'),
        const PsgcLocation(code: '043422000', name: 'Pila'),
        const PsgcLocation(code: '043423000', name: 'Rizal'),
        const PsgcLocation(code: '043424000', name: 'City of San Pablo'),
        const PsgcLocation(code: '043425000', name: 'City of San Pedro'),
        const PsgcLocation(code: '043426000', name: 'Santa Cruz'),
        const PsgcLocation(code: '043427000', name: 'Santa Maria'),
        const PsgcLocation(code: '043428000', name: 'City of Santa Rosa'),
        const PsgcLocation(code: '043429000', name: 'Siniloan'),
        const PsgcLocation(code: '043430000', name: 'Victoria'),
      ];
    } else if (provinceCode == '130000000') {
      // Metro Manila cities & municipalities
      return [
        const PsgcLocation(code: '137501000', name: 'City of Caloocan'),
        const PsgcLocation(code: '137601000', name: 'City of Las Piñas'),
        const PsgcLocation(code: '137602000', name: 'City of Makati'),
        const PsgcLocation(code: '137502000', name: 'City of Malabon'),
        const PsgcLocation(code: '137401000', name: 'City of Mandaluyong'),
        const PsgcLocation(code: '133900000', name: 'City of Manila'),
        const PsgcLocation(code: '137402000', name: 'City of Marikina'),
        const PsgcLocation(code: '137603000', name: 'City of Muntinlupa'),
        const PsgcLocation(code: '137503000', name: 'City of Navotas'),
        const PsgcLocation(code: '137604000', name: 'City of Parañaque'),
        const PsgcLocation(code: '137605000', name: 'Pasay City'),
        const PsgcLocation(code: '137403000', name: 'City of Pasig'),
        const PsgcLocation(code: '137606000', name: 'Pateros'),
        const PsgcLocation(code: '137404000', name: 'Quezon City'),
        const PsgcLocation(code: '137405000', name: 'City of San Juan'),
        const PsgcLocation(code: '137607000', name: 'City of Taguig'),
        const PsgcLocation(code: '137504000', name: 'City of Valenzuela'),
      ];
    }
    return [];
  }

  static List<PsgcLocation> _getFallbackBarangays(String cityCode) {
    if (cityCode == '043422000') {
      // Pila barangays
      return [
        const PsgcLocation(code: '043422001', name: 'Aplaya'),
        const PsgcLocation(code: '043422002', name: 'Bagong Pook'),
        const PsgcLocation(code: '043422003', name: 'Bukal'),
        const PsgcLocation(code: '043422004', name: 'Bulilan Norte (Pob.)'),
        const PsgcLocation(code: '043422005', name: 'Bulilan Sur (Pob.)'),
        const PsgcLocation(code: '043422006', name: 'Concepcion'),
        const PsgcLocation(code: '043422007', name: 'Labuin'),
        const PsgcLocation(code: '043422008', name: 'Linga'),
        const PsgcLocation(code: '043422009', name: 'Masico'),
        const PsgcLocation(code: '043422010', name: 'Mojon'),
        const PsgcLocation(code: '043422011', name: 'Pansol'),
        const PsgcLocation(code: '043422012', name: 'Pinagbayanan'),
        const PsgcLocation(code: '043422014', name: 'San Antonio'),
        const PsgcLocation(code: '043422015', name: 'San Miguel'),
        const PsgcLocation(code: '043422016', name: 'Santa Clara Norte (Pob.)'),
        const PsgcLocation(code: '043422017', name: 'Santa Clara Sur (Pob.)'),
        const PsgcLocation(code: '043422018', name: 'Tubuan'),
      ];
    } else if (cityCode == '043426000') {
      // Santa Cruz barangays
      return [
        const PsgcLocation(code: '043426001', name: 'Alipit'),
        const PsgcLocation(code: '043426002', name: 'Bagumbayan'),
        const PsgcLocation(code: '043426003', name: 'Bubukal'),
        const PsgcLocation(code: '043426004', name: 'Calios'),
        const PsgcLocation(code: '043426005', name: 'Duhat'),
        const PsgcLocation(code: '043426006', name: 'Gatid'),
        const PsgcLocation(code: '043426007', name: 'Jonsor'),
        const PsgcLocation(code: '043426008', name: 'Labuin'),
        const PsgcLocation(code: '043426009', name: 'Malinao'),
        const PsgcLocation(code: '043426010', name: 'Oogong'),
        const PsgcLocation(code: '043426011', name: 'Pagsawitan'),
        const PsgcLocation(code: '043426012', name: 'Palasan'),
        const PsgcLocation(code: '043426013', name: 'Patimbao'),
        const PsgcLocation(code: '043426014', name: 'Poblacion I'),
        const PsgcLocation(code: '043426015', name: 'Poblacion II'),
        const PsgcLocation(code: '043426016', name: 'Poblacion III'),
        const PsgcLocation(code: '043426017', name: 'Poblacion IV'),
        const PsgcLocation(code: '043426018', name: 'Poblacion V'),
        const PsgcLocation(code: '043426019', name: 'San Jose'),
        const PsgcLocation(code: '043426020', name: 'San Juan'),
        const PsgcLocation(code: '043426021', name: 'San Nicolas'),
        const PsgcLocation(code: '043426022', name: 'Santisima Cruz'),
        const PsgcLocation(code: '043426023', name: 'Santo Angel Central'),
        const PsgcLocation(code: '043426024', name: 'Santo Angel Norte'),
        const PsgcLocation(code: '043426025', name: 'Santo Angel Sur'),
      ];
    } else if (cityCode == '137405000') {
      // San Juan, Metro Manila
      return [
        const PsgcLocation(code: '137405001', name: 'Addition Hills'),
        const PsgcLocation(code: '137405002', name: 'Balong-Bato'),
        const PsgcLocation(code: '137405003', name: 'Batis'),
        const PsgcLocation(code: '137405004', name: 'Corazon de Jesus'),
        const PsgcLocation(code: '137405005', name: 'Greenhills'),
        const PsgcLocation(code: '137405006', name: 'Isabelita'),
        const PsgcLocation(code: '137405007', name: 'Kabayanan'),
        const PsgcLocation(code: '137405008', name: 'Little Baguio'),
        const PsgcLocation(code: '137405009', name: 'Maytunas'),
        const PsgcLocation(code: '137405010', name: 'Onse'),
        const PsgcLocation(code: '137405011', name: 'Pasadeña'),
        const PsgcLocation(code: '137405012', name: 'Pedro Cruz'),
        const PsgcLocation(code: '137405013', name: 'Progreso'),
        const PsgcLocation(code: '137405014', name: 'Rivera'),
        const PsgcLocation(code: '137405015', name: 'Salapan'),
        const PsgcLocation(code: '137405016', name: 'San Perfecto'),
        const PsgcLocation(code: '137405017', name: 'Santa Lucia'),
        const PsgcLocation(code: '137405018', name: 'Tibagan'),
        const PsgcLocation(code: '137405019', name: 'West Crame'),
      ];
    }
    return [];
  }
}
