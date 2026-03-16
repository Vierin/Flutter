import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../models/staff_member.dart';

class StaffApiService {
  /// GET /staff?salonId= — список сотрудников салона.
  static Future<List<StaffMember>> getBySalon(
    String accessToken,
    String salonId,
  ) async {
    try {
      final list = await ApiClient.get(
        '/staff?salonId=${Uri.encodeComponent(salonId)}',
        accessToken,
      );
      if (list is! List) return [];
      final result = <StaffMember>[];
      for (final item in list) {
        if (item is! Map) continue;
        try {
          final member = StaffMember.fromJson(Map<String, dynamic>.from(item));
          if (member.id.isNotEmpty) result.add(member);
        } catch (_) {}
      }
      return result;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[StaffAPI] getBySalon: $e');
      return [];
    }
  }

  /// POST /staff — создать сотрудника.
  static Future<StaffMember?> create(
    String accessToken, {
    required String salonId,
    required String name,
    String? email,
    String? phone,
    String accessLevel = 'EMPLOYEE',
    List<String>? serviceIds,
  }) async {
    try {
      final body = <String, dynamic>{
        'salonId': salonId,
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'accessLevel': accessLevel,
        if (serviceIds != null && serviceIds.isNotEmpty)
          'serviceIds': serviceIds,
      };
      final map =
          await ApiClient.post('/staff', accessToken, body: body)
              as Map<String, dynamic>?;
      return map != null ? StaffMember.fromJson(map) : null;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[StaffAPI] create: $e');
      return null;
    }
  }

  /// PUT /staff/:id — обновить сотрудника.
  static Future<StaffMember?> update(
    String accessToken,
    String id, {
    String? name,
    String? email,
    String? phone,
    String? accessLevel,
    List<String>? serviceIds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (accessLevel != null) data['accessLevel'] = accessLevel;
      if (serviceIds != null) data['serviceIds'] = serviceIds;
      final map =
          await ApiClient.put(
                '/staff/$id',
                accessToken,
                body: data.isEmpty ? null : data,
              )
              as Map<String, dynamic>?;
      return map != null ? StaffMember.fromJson(map) : null;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[StaffAPI] update: $e');
      return null;
    }
  }

  /// DELETE /staff/:id — удалить сотрудника.
  static Future<bool> delete(String accessToken, String id) async {
    try {
      await ApiClient.delete('/staff/$id', accessToken);
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[StaffAPI] delete: $e');
      return false;
    }
  }
}
