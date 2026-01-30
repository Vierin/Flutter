import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Вызовы Mapbox через бэкенд (GET /mapbox/...).
class MapboxApiService {
  static String get _baseUrl => AppConfig.apiUrl;

  /// GET /mapbox/autocomplete?q= — подсказки адресов.
  static Future<List<AddressSuggestion>> getAutocomplete(
    String query, {
    String country = 'VN',
    int limit = 5,
  }) async {
    if (query.trim().length < 2) return [];
    final url = Uri.parse(
      '$_baseUrl/mapbox/autocomplete?q=${Uri.encodeQueryComponent(query.trim())}&country=$country&limit=$limit',
    );
    try {
      final response = await http.get(url);
      if (kDebugMode) {
        debugPrint('[MapboxAPI] GET autocomplete status=${response.statusCode}');
      }
      if (response.statusCode != 200) return [];
      final list = json.decode(response.body);
      if (list is! List) return [];
      final result = <AddressSuggestion>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final m = Map<String, dynamic>.from(item);
          final id = m['id']?.toString() ?? '';
          final address = m['address'] as String? ?? '';
          final lat = (m['lat'] is num) ? (m['lat'] as num).toDouble() : 0.0;
          final lon = (m['lon'] is num) ? (m['lon'] as num).toDouble() : 0.0;
          if (address.isNotEmpty) result.add(AddressSuggestion(id: id, address: address, lat: lat, lon: lon));
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[MapboxAPI] autocomplete error: $e');
      return [];
    }
  }

  /// GET /mapbox/reverse-geocode?lat=&lon= — адрес по координатам.
  static Future<ReverseGeocodeResult?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse('$_baseUrl/mapbox/reverse-geocode?lat=$lat&lon=$lon');
    try {
      final response = await http.get(url);
      if (kDebugMode) {
        debugPrint('[MapboxAPI] GET reverse-geocode status=${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final m = Map<String, dynamic>.from(data);
      final address = m['address'] as String? ?? '';
      final latRes = (m['lat'] is num) ? (m['lat'] as num).toDouble() : lat;
      final lonRes = (m['lon'] is num) ? (m['lon'] as num).toDouble() : lon;
      return ReverseGeocodeResult(address: address, lat: latRes, lon: lonRes);
    } catch (e) {
      if (kDebugMode) debugPrint('[MapboxAPI] reverse-geocode error: $e');
      return null;
    }
  }
}

class AddressSuggestion {
  final String id;
  final String address;
  final double lat;
  final double lon;

  AddressSuggestion({
    required this.id,
    required this.address,
    required this.lat,
    required this.lon,
  });
}

class ReverseGeocodeResult {
  final String address;
  final double lat;
  final double lon;

  ReverseGeocodeResult({
    required this.address,
    required this.lat,
    required this.lon,
  });
}
