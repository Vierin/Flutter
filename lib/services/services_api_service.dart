import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/service_item.dart';

class ServicesApiService {
  static String get _baseUrl => AppConfig.apiUrl;

  static Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      };

  /// GET /services?salonId= — список услуг салона.
  static Future<List<ServiceItem>> getBySalon(
      String accessToken, String salonId) async {
    final url = Uri.parse('$_baseUrl/services?salonId=$salonId');
    final response = await http.get(url, headers: _headers(accessToken));
    if (kDebugMode) {
      debugPrint(
          '[ServicesAPI] GET /services?salonId= status=${response.statusCode}');
    }
    if (response.statusCode != 200) return [];
    final body = json.decode(response.body);
    final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] as List : <dynamic>[]);
    final result = <ServiceItem>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        final service = ServiceItem.fromJson(Map<String, dynamic>.from(item));
        if (service.id.isNotEmpty) result.add(service);
      } catch (e) {
        if (kDebugMode) debugPrint('[ServicesAPI] parse error: $e for item: $item');
      }
    }
    return result;
  }

  /// POST /services — создать услугу (duration и price обязательны на бекенде).
  static Future<ServiceItem?> create(
    String accessToken, {
    required String salonId,
    required String name,
    required double price,
    required int duration,
  }) async {
    final url = Uri.parse('$_baseUrl/services');
    final body = json.encode({
      'salonId': salonId,
      'name': name,
      'price': price,
      'duration': duration,
    });
    final response = await http.post(
      url,
      headers: _headers(accessToken),
      body: body,
    );
    if (kDebugMode) {
      debugPrint('[ServicesAPI] POST /services status=${response.statusCode}');
    }
    if (response.statusCode != 200 && response.statusCode != 201) return null;
    final map = json.decode(response.body) as Map<String, dynamic>?;
    return map != null ? ServiceItem.fromJson(map) : null;
  }

  /// PUT /services/:id — обновить услугу.
  static Future<ServiceItem?> update(
    String accessToken,
    String id, {
    String? name,
    String? description,
    double? price,
    int? duration,
  }) async {
    final url = Uri.parse('$_baseUrl/services/$id');
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (price != null) data['price'] = price;
    if (duration != null) data['duration'] = duration;
    final response = await http.put(
      url,
      headers: _headers(accessToken),
      body: json.encode(data),
    );
    if (kDebugMode) {
      debugPrint('[ServicesAPI] PUT /services/$id status=${response.statusCode}');
    }
    if (response.statusCode != 200) return null;
    final map = json.decode(response.body) as Map<String, dynamic>?;
    return map != null ? ServiceItem.fromJson(map) : null;
  }

  /// DELETE /services/:id — удалить услугу.
  static Future<bool> delete(String accessToken, String id) async {
    final url = Uri.parse('$_baseUrl/services/$id');
    final response = await http.delete(url, headers: _headers(accessToken));
    if (kDebugMode) {
      debugPrint(
          '[ServicesAPI] DELETE /services/$id status=${response.statusCode}');
    }
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
