import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../models/booking.dart';
import '../models/salon.dart';
import '../models/subscription.dart';
import '../models/time_block.dart';

class DashboardApiService {
  /// GET /salons/current — салон владельца.
  static Future<Salon?> getCurrentSalon(String accessToken) async {
    try {
      final body = await ApiClient.get('/salons/current', accessToken);
      if (body is! Map<String, dynamic>) return null;
      if (body['success'] != true) {
        if (kDebugMode) debugPrint('[DashboardAPI] salon success=false');
        return null;
      }
      final data = body['data'];
      if (data == null || data is! Map<String, dynamic>) return null;
      return Salon.fromJson(Map<String, dynamic>.from(data));
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getCurrentSalon: $e');
      return null;
    }
  }

  /// PUT /salons/current — обновить салон владельца.
  static Future<Salon> updateCurrentSalon(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final data =
        await ApiClient.put('/salons/current', accessToken, body: payload)
            as Map<String, dynamic>?;
    if (data == null) throw ApiException('Invalid response');
    return Salon.fromJson(data);
  }

  /// POST /salons/current — создать салон владельца.
  static Future<Salon> createCurrentSalon(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final data =
        await ApiClient.post('/salons/current', accessToken, body: payload)
            as Map<String, dynamic>?;
    if (data == null) throw ApiException('Invalid response');
    return Salon.fromJson(data);
  }

  /// GET /subscriptions/current — текущая подписка владельца.
  static Future<Subscription?> getCurrentSubscription(
    String accessToken,
  ) async {
    try {
      final body = await ApiClient.get('/subscriptions/current', accessToken);
      if (body is! Map<String, dynamic>) return null;
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return Subscription.fromJson(Map<String, dynamic>.from(data));
      }
      return Subscription.fromJson(body);
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getCurrentSubscription: $e');
      return null;
    }
  }

  /// GET /bookings/owner — бронирования владельца.
  static Future<List<Booking>> getOwnerBookings(String accessToken) async {
    final list = await ApiClient.get('/bookings/owner?limit=100', accessToken);
    if (list is! List) return [];
    final result = <Booking>[];
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
  }

  /// PUT /bookings/:id/confirm — подтвердить бронирование.
  static Future<bool> confirmBooking(
    String accessToken,
    String bookingId,
  ) async {
    await ApiClient.put('/bookings/$bookingId/confirm', accessToken);
    return true;
  }

  /// GET /time-blocks — блокировки времени салона.
  static Future<List<TimeBlock>> getTimeBlocks(
    String accessToken, {
    String? startDate,
    String? endDate,
    String? staffId,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;
    if (staffId != null) params['staffId'] = staffId;
    final path = params.isEmpty
        ? '/time-blocks'
        : '/time-blocks?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    try {
      final list = await ApiClient.get(path, accessToken);
      if (list is! List) return [];
      final result = <TimeBlock>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(TimeBlock.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            if (kDebugMode)
              debugPrint('[DashboardAPI] timeBlock parse error: $e');
          }
        }
      }
      return result;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[DashboardAPI] getTimeBlocks: $e');
      return [];
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
    final body = <String, dynamic>{
      'salonId': salonId,
      'serviceId': serviceId,
      'time': timeIso,
      if (staffId != null && staffId.isNotEmpty) 'staffId': staffId,
      if (clientName != null && clientName.isNotEmpty) 'clientName': clientName,
      if (clientPhone != null && clientPhone.isNotEmpty)
        'clientPhone': clientPhone,
      if (clientEmail != null && clientEmail.isNotEmpty)
        'clientEmail': clientEmail,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final data =
        await ApiClient.post('/bookings', accessToken, body: body)
            as Map<String, dynamic>?;
    if (data == null) throw ApiException('Invalid response');
    final booking = data['booking'];
    if (booking is! Map<String, dynamic>)
      throw ApiException('No booking in response');
    return _bookingFromApi(Map<String, dynamic>.from(booking));
  }

  /// PUT /bookings/:id/reject — отклонить бронирование.
  static Future<bool> rejectBooking(
    String accessToken,
    String bookingId,
  ) async {
    await ApiClient.put('/bookings/$bookingId/reject', accessToken);
    return true;
  }

  /// PUT /bookings/:id/cancel — отменить бронирование.
  static Future<bool> cancelBooking(
    String accessToken,
    String bookingId,
  ) async {
    await ApiClient.put('/bookings/$bookingId/cancel', accessToken);
    return true;
  }

  /// PUT /bookings/:id — обновить бронирование.
  static Future<Booking> updateBooking(
    String accessToken,
    String bookingId, {
    String? serviceId,
    String? staffId,
    String? timeIso,
    String? notes,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (serviceId != null && serviceId.isNotEmpty)
      body['serviceId'] = serviceId;
    if (staffId != null && staffId.isNotEmpty) body['staffId'] = staffId;
    if (timeIso != null && timeIso.isNotEmpty) body['time'] = timeIso;
    if (notes != null) body['notes'] = notes;
    if (status != null && status.isNotEmpty) body['status'] = status;
    final data =
        await ApiClient.put(
              '/bookings/$bookingId',
              accessToken,
              body: body.isEmpty ? null : body,
            )
            as Map<String, dynamic>?;
    if (data == null) throw ApiException('Invalid response');
    final booking = data['booking'];
    if (booking is! Map<String, dynamic>)
      throw ApiException('No booking in response');
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
