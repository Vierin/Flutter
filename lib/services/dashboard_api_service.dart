import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/booking.dart';
import '../models/salon.dart';
import '../models/subscription.dart';
import '../models/time_block.dart';

class DashboardApiService {
  static String get _baseUrl => AppConfig.apiUrl;

  /// GET /salons/current — салон владельца.
  static Future<Salon?> getCurrentSalon(String accessToken) async {
    final url = Uri.parse('$_baseUrl/salons/current');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (kDebugMode) {
        debugPrint('[DashboardAPI] GET /salons/current status=${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body) as Map<String, dynamic>?;
      if (body == null || body['success'] != true) {
        if (kDebugMode) debugPrint('[DashboardAPI] salon success=false or no body');
        return null;
      }
      final data = body['data'];
      if (data == null || data is! Map<String, dynamic>) return null;
      return Salon.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getCurrentSalon error: $e');
      rethrow;
    }
  }

  /// PUT /salons/current — обновить салон владельца.
  static Future<Salon> updateCurrentSalon(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final url = Uri.parse('$_baseUrl/salons/current');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: json.encode(payload),
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] PUT /salons/current status=${response.statusCode}');
    }
    if (response.statusCode != 200) {
      throw Exception(_errorMessageFromResponse(response));
    }
    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) throw Exception('Invalid response');
    return Salon.fromJson(Map<String, dynamic>.from(data));
  }

  /// POST /salons/current — создать салон владельца.
  static Future<Salon> createCurrentSalon(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final url = Uri.parse('$_baseUrl/salons/current');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: json.encode(payload),
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] POST /salons/current status=${response.statusCode}');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessageFromResponse(response));
    }
    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) throw Exception('Invalid response');
    return Salon.fromJson(Map<String, dynamic>.from(data));
  }

  /// GET /subscriptions/current — текущая подписка владельца.
  static Future<Subscription?> getCurrentSubscription(String accessToken) async {
    final url = Uri.parse('$_baseUrl/subscriptions/current');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (kDebugMode) {
        debugPrint('[DashboardAPI] GET /subscriptions/current status=${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          return Subscription.fromJson(Map<String, dynamic>.from(data));
        }
        return Subscription.fromJson(body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getCurrentSubscription error: $e');
      return null;
    }
  }

  /// GET /bookings/owner — бронирования владельца.
  static Future<List<Booking>> getOwnerBookings(String accessToken) async {
    final url = Uri.parse('$_baseUrl/bookings/owner?limit=100');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (kDebugMode) {
        debugPrint('[DashboardAPI] GET /bookings/owner status=${response.statusCode} count=${response.body.length}');
      }
      if (response.statusCode != 200) return [];
      final list = json.decode(response.body);
      if (list is! List) return [];
      final List<Booking> result = [];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(_bookingFromApi(Map<String, dynamic>.from(item)));
          } catch (e) {
            if (kDebugMode) debugPrint('[DashboardAPI] booking parse error: $e');
          }
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getOwnerBookings error: $e');
      rethrow;
    }
  }

  /// Читает сообщение об ошибке из JSON ответа бекенда (поле msg или message).
  static String _errorMessageFromResponse(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map<String, dynamic>) {
        final msg = body['msg'] as String? ?? body['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  /// PUT /bookings/:id/confirm — подтвердить бронирование.
  static Future<bool> confirmBooking(String accessToken, String bookingId) async {
    final url = Uri.parse('$_baseUrl/bookings/$bookingId/confirm');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] PUT /bookings/$bookingId/confirm status=${response.statusCode}');
    }
    if (response.statusCode == 200) return true;
    throw Exception(_errorMessageFromResponse(response));
  }

  /// GET /time-blocks — блокировки времени салона.
  static Future<List<TimeBlock>> getTimeBlocks(
    String accessToken, {
    String? startDate,
    String? endDate,
    String? staffId,
  }) async {
    var url = Uri.parse('$_baseUrl/time-blocks');
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;
    if (staffId != null) params['staffId'] = staffId;
    if (params.isNotEmpty) {
      url = url.replace(queryParameters: params);
    }
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (kDebugMode) {
        debugPrint('[DashboardAPI] GET /time-blocks status=${response.statusCode}');
      }
      if (response.statusCode != 200) return [];
      final list = json.decode(response.body);
      if (list is! List) return [];
      final List<TimeBlock> result = [];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(TimeBlock.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            if (kDebugMode) debugPrint('[DashboardAPI] timeBlock parse error: $e');
          }
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getTimeBlocks error: $e');
      rethrow;
    }
  }

  /// POST /bookings — создать бронирование (владелец от имени клиента).
  static Future<Booking> createBooking(
    String accessToken, {
    required String salonId,
    required String serviceId,
    required String timeIso,
    String? staffId,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    String? notes,
  }) async {
    final url = Uri.parse('$_baseUrl/bookings');
    final body = <String, dynamic>{
      'salonId': salonId,
      'serviceId': serviceId,
      'time': timeIso,
      if (staffId != null && staffId.isNotEmpty) 'staffId': staffId,
      if (clientName != null && clientName.isNotEmpty) 'clientName': clientName,
      if (clientPhone != null && clientPhone.isNotEmpty) 'clientPhone': clientPhone,
      if (clientEmail != null && clientEmail.isNotEmpty) 'clientEmail': clientEmail,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: json.encode(body),
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] POST /bookings status=${response.statusCode}');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessageFromResponse(response));
    }
    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) throw Exception('Invalid response');
    final booking = data['booking'];
    if (booking is! Map<String, dynamic>) throw Exception('No booking in response');
    return _bookingFromApi(booking);
  }

  /// PUT /bookings/:id/reject — отклонить бронирование.
  static Future<bool> rejectBooking(String accessToken, String bookingId) async {
    final url = Uri.parse('$_baseUrl/bookings/$bookingId/reject');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] PUT /bookings/$bookingId/reject status=${response.statusCode}');
    }
    if (response.statusCode == 200) return true;
    throw Exception(_errorMessageFromResponse(response));
  }

  /// PUT /bookings/:id/cancel — отменить бронирование.
  static Future<bool> cancelBooking(String accessToken, String bookingId) async {
    final url = Uri.parse('$_baseUrl/bookings/$bookingId/cancel');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] PUT /bookings/$bookingId/cancel status=${response.statusCode}');
    }
    if (response.statusCode == 200) return true;
    throw Exception(_errorMessageFromResponse(response));
  }

  /// PUT /bookings/:id — обновить бронирование (serviceId, staffId, time, notes, status).
  static Future<Booking> updateBooking(
    String accessToken,
    String bookingId, {
    String? serviceId,
    String? staffId,
    String? timeIso,
    String? notes,
    String? status,
  }) async {
    final url = Uri.parse('$_baseUrl/bookings/$bookingId');
    final body = <String, dynamic>{};
    if (serviceId != null && serviceId.isNotEmpty) body['serviceId'] = serviceId;
    if (staffId != null && staffId.isNotEmpty) body['staffId'] = staffId;
    if (timeIso != null && timeIso.isNotEmpty) body['time'] = timeIso;
    if (notes != null) body['notes'] = notes;
    if (status != null && status.isNotEmpty) body['status'] = status;
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: json.encode(body),
    );
    if (kDebugMode) {
      debugPrint('[DashboardAPI] PUT /bookings/$bookingId status=${response.statusCode}');
    }
    if (response.statusCode != 200) {
      throw Exception(_errorMessageFromResponse(response));
    }
    final data = json.decode(response.body) as Map<String, dynamic>?;
    if (data == null) throw Exception('Invalid response');
    final booking = data['booking'];
    if (booking is! Map<String, dynamic>) throw Exception('No booking in response');
    return _bookingFromApi(Map<String, dynamic>.from(booking));
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
