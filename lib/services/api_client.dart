import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thrown when API returns non-2xx. [message] is from body (msg/message) or status.
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Shared HTTP client for backend API: base URL, Bearer auth, timeout, error parsing.
class ApiClient {
  ApiClient._();

  static String get _baseUrl => AppConfig.apiUrl;

  static const Duration _timeout = Duration(seconds: 30);

  static Map<String, String> _headers(String? accessToken) {
    final map = <String, String>{
      'Content-Type': 'application/json',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      map['authorization'] = 'Bearer $accessToken';
    }
    return map;
  }

  /// Parse error message from response body (msg or message) or fallback to status.
  static String errorMessageFromResponse(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map<String, dynamic>) {
        final msg = body['msg'] as String? ?? body['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  static void _throwIfNotSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(errorMessageFromResponse(response), response.statusCode);
  }

  /// GET [path] (relative to base URL). Returns decoded JSON. Throws [ApiException] on non-2xx.
  static Future<dynamic> get(String path, String? accessToken) async {
    final url = Uri.parse('$_baseUrl$path');
    if (kDebugMode) debugPrint('[ApiClient] GET $path');
    final response = await http
        .get(url, headers: _headers(accessToken))
        .timeout(_timeout);
    if (kDebugMode) debugPrint('[ApiClient] GET $path status=${response.statusCode}');
    _throwIfNotSuccess(response);
    if (response.body.isEmpty) return null;
    return json.decode(response.body);
  }

  /// POST [path] with optional [body]. Returns decoded JSON. Throws [ApiException] on non-2xx.
  static Future<dynamic> post(
    String path,
    String? accessToken, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    if (kDebugMode) debugPrint('[ApiClient] POST $path');
    final response = await http
        .post(
          url,
          headers: _headers(accessToken),
          body: body != null ? json.encode(body) : null,
        )
        .timeout(_timeout);
    if (kDebugMode) debugPrint('[ApiClient] POST $path status=${response.statusCode}');
    _throwIfNotSuccess(response);
    if (response.body.isEmpty) return null;
    return json.decode(response.body);
  }

  /// PUT [path] with optional [body]. Returns decoded JSON. Throws [ApiException] on non-2xx.
  static Future<dynamic> put(
    String path,
    String? accessToken, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    if (kDebugMode) debugPrint('[ApiClient] PUT $path');
    final response = await http
        .put(
          url,
          headers: _headers(accessToken),
          body: body != null ? json.encode(body) : null,
        )
        .timeout(_timeout);
    if (kDebugMode) debugPrint('[ApiClient] PUT $path status=${response.statusCode}');
    _throwIfNotSuccess(response);
    if (response.body.isEmpty) return null;
    return json.decode(response.body);
  }

  /// DELETE [path]. Returns decoded JSON. Throws [ApiException] on non-2xx.
  static Future<dynamic> delete(String path, String? accessToken) async {
    final url = Uri.parse('$_baseUrl$path');
    if (kDebugMode) debugPrint('[ApiClient] DELETE $path');
    final response = await http
        .delete(url, headers: _headers(accessToken))
        .timeout(_timeout);
    if (kDebugMode) debugPrint('[ApiClient] DELETE $path status=${response.statusCode}');
    _throwIfNotSuccess(response);
    if (response.body.isEmpty) return null;
    return json.decode(response.body);
  }
}
