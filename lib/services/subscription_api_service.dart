import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/subscription.dart';

/// Интервал подписки (как в веб).
typedef SubscriptionInterval = String; // 'monthly' | 'annual'

class SubscriptionApiService {
  static String get _baseUrl => AppConfig.apiUrl;

  /// GET /subscriptions/current — текущая подписка владельца.
  static Future<Subscription?> getCurrent(String accessToken) async {
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
        debugPrint(
          '[SubscriptionAPI] GET /subscriptions/current status=${response.statusCode}',
        );
      }
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) return null;
      return Subscription.fromJson(body);
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] getCurrent error: $e');
      rethrow;
    }
  }

  /// GET /subscriptions/invoices — список счетов.
  static Future<List<SubscriptionInvoice>> getInvoices(
    String accessToken,
  ) async {
    final url = Uri.parse('$_baseUrl/subscriptions/invoices');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode != 200) return [];
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) return [];
      final list = body['invoices'];
      if (list is! List) return [];
      return list
          .map(
            (e) => SubscriptionInvoice.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] getInvoices error: $e');
      return [];
    }
  }

  /// POST /subscriptions/create-checkout-session — URL для оплаты.
  static Future<String?> createCheckoutSession(
    String accessToken,
    SubscriptionInterval interval,
  ) async {
    final url = Uri.parse('$_baseUrl/subscriptions/create-checkout-session');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
        body: json.encode({'interval': interval}),
      );
      if (kDebugMode) {
        debugPrint(
          '[SubscriptionAPI] create-checkout status=${response.statusCode}',
        );
      }
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body) as Map<String, dynamic>?;
      return body?['url'] as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SubscriptionAPI] createCheckoutSession error: $e');
      }
      rethrow;
    }
  }

  /// POST /subscriptions/create-portal-session — URL портала Stripe.
  static Future<String?> createPortalSession(String accessToken) async {
    final url = Uri.parse('$_baseUrl/subscriptions/create-portal-session');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body) as Map<String, dynamic>?;
      return body?['url'] as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SubscriptionAPI] createPortalSession error: $e');
      }
      rethrow;
    }
  }

  /// POST /subscriptions/cancel — отмена в конце периода.
  static Future<bool> cancel(String accessToken) async {
    final url = Uri.parse('$_baseUrl/subscriptions/cancel');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] cancel error: $e');
      rethrow;
    }
  }

  /// POST /subscriptions/confirm-checkout — подтверждение после редиректа.
  static Future<bool> confirmCheckout(
    String accessToken,
    String sessionId,
  ) async {
    final url = Uri.parse('$_baseUrl/subscriptions/confirm-checkout');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
        body: json.encode({'session_id': sessionId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] confirmCheckout error: $e');
      return false;
    }
  }
}
