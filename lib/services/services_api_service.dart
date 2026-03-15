import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../models/service_item.dart';

class ServicesApiService {
  /// GET /services?salonId= — список услуг салона.
  static Future<List<ServiceItem>> getBySalon(
    String accessToken,
    String salonId,
  ) async {
    try {
      final body = await ApiClient.get(
        '/services?salonId=${Uri.encodeComponent(salonId)}',
        accessToken,
      );
      final list = body is List
          ? body
          : (body is Map && body['data'] is List
              ? body['data'] as List
              : <dynamic>[]);
      final result = <ServiceItem>[];
      for (final item in list) {
        if (item is! Map) continue;
        try {
          final service = ServiceItem.fromJson(Map<String, dynamic>.from(item));
          if (service.id.isNotEmpty) result.add(service);
        } catch (e) {
          if (kDebugMode) debugPrint('[ServicesAPI] parse error: $e');
        }
      }
      return result;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[ServicesAPI] getBySalon: $e');
      return [];
    }
  }

  /// POST /services — создать услугу.
  static Future<ServiceItem?> create(
    String accessToken, {
    required String salonId,
    required String name,
    required double price,
    required int duration,
  }) async {
    try {
      final map = await ApiClient.post(
        '/services',
        accessToken,
        body: {
          'salonId': salonId,
          'name': name,
          'price': price,
          'duration': duration,
        },
      ) as Map<String, dynamic>?;
      return map != null ? ServiceItem.fromJson(map) : null;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[ServicesAPI] create: $e');
      return null;
    }
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
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (price != null) data['price'] = price;
      if (duration != null) data['duration'] = duration;
      final map = await ApiClient.put(
        '/services/$id',
        accessToken,
        body: data.isEmpty ? null : data,
      ) as Map<String, dynamic>?;
      return map != null ? ServiceItem.fromJson(map) : null;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[ServicesAPI] update: $e');
      return null;
    }
  }

  /// DELETE /services/:id — удалить услугу.
  static Future<bool> delete(String accessToken, String id) async {
    try {
      await ApiClient.delete('/services/$id', accessToken);
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[ServicesAPI] delete: $e');
      return false;
    }
  }
}
