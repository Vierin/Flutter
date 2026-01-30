import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/booking.dart';
import '../models/salon.dart';

class DashboardApiService {
  static String get _baseUrl => AppConfig.apiUrl;

  /// GET /salons/current — салон владельца.
  static Future<Salon?> getCurrentSalon(String accessToken) async {
    final url = Uri.parse('$_baseUrl/salons/current');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode != 200) return null;
    final body = json.decode(response.body) as Map<String, dynamic>?;
    if (body == null || body['success'] != true) return null;
    final data = body['data'];
    if (data == null || data is! Map<String, dynamic>) return null;
    return Salon.fromJson(data);
  }

  /// GET /bookings/owner — бронирования владельца.
  static Future<List<Booking>> getOwnerBookings(String accessToken) async {
    final url = Uri.parse('$_baseUrl/bookings/owner?limit=100');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode != 200) return [];
    final list = json.decode(response.body);
    if (list is! List) return [];
    final List<Booking> result = [];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        try {
          result.add(_bookingFromApi(item));
        } catch (_) {}
      }
    }
    return result;
  }

  /// Бекенд отдаёт time (ISO строка), фронт ожидает dateTime.
  static Booking _bookingFromApi(Map<String, dynamic> json) {
    final time = json['time'];
    String? dateTimeStr;
    if (time is String) {
      dateTimeStr = time;
    } else if (time != null) {
      dateTimeStr = time.toString();
    }
    final map = Map<String, dynamic>.from(json);
    map['dateTime'] = dateTimeStr ?? DateTime.now().toIso8601String();
    return Booking.fromJson(map);
  }
}
