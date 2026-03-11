import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/staff_member.dart';

class StaffApiService {
  static String get _baseUrl => AppConfig.apiUrl;

  static Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'authorization': 'Bearer $accessToken',
      };

  /// GET /staff?salonId= — список сотрудников салона.
  static Future<List<StaffMember>> getBySalon(
      String accessToken, String salonId) async {
    final url = Uri.parse('$_baseUrl/staff?salonId=$salonId');
    final response = await http.get(url, headers: _headers(accessToken));
    if (kDebugMode) {
      debugPrint('[StaffAPI] GET /staff?salonId= status=${response.statusCode}');
    }
    if (response.statusCode != 200) return [];
    final list = json.decode(response.body);
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
  }

  /// POST /staff — создать сотрудника (как на вебе: name, email, phone, serviceIds).
  static Future<StaffMember?> create(
    String accessToken, {
    required String salonId,
    required String name,
    String? email,
    String? phone,
    String accessLevel = 'EMPLOYEE',
    List<String>? serviceIds,
  }) async {
    final url = Uri.parse('$_baseUrl/staff');
    final body = json.encode({
      'salonId': salonId,
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'accessLevel': accessLevel,
      if (serviceIds != null && serviceIds.isNotEmpty) 'serviceIds': serviceIds,
    });
    final response = await http.post(
      url,
      headers: _headers(accessToken),
      body: body,
    );
    if (kDebugMode) {
      debugPrint('[StaffAPI] POST /staff status=${response.statusCode}');
    }
    if (response.statusCode != 200 && response.statusCode != 201) return null;
    final map = json.decode(response.body) as Map<String, dynamic>?;
    return map != null ? StaffMember.fromJson(map) : null;
  }

  /// PUT /staff/:id — обновить сотрудника (name, email, phone, accessLevel, serviceIds).
  static Future<StaffMember?> update(
    String accessToken,
    String id, {
    String? name,
    String? email,
    String? phone,
    String? accessLevel,
    List<String>? serviceIds,
  }) async {
    final url = Uri.parse('$_baseUrl/staff/$id');
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (accessLevel != null) data['accessLevel'] = accessLevel;
    if (serviceIds != null) data['serviceIds'] = serviceIds;
    final response = await http.put(
      url,
      headers: _headers(accessToken),
      body: json.encode(data),
    );
    if (kDebugMode) {
      debugPrint('[StaffAPI] PUT /staff/$id status=${response.statusCode}');
    }
    if (response.statusCode != 200) return null;
    final map = json.decode(response.body) as Map<String, dynamic>?;
    return map != null ? StaffMember.fromJson(map) : null;
  }

  /// DELETE /staff/:id — удалить сотрудника.
  static Future<bool> delete(String accessToken, String id) async {
    final url = Uri.parse('$_baseUrl/staff/$id');
    final response = await http.delete(url, headers: _headers(accessToken));
    if (kDebugMode) {
      debugPrint('[StaffAPI] DELETE /staff/$id status=${response.statusCode}');
    }
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
