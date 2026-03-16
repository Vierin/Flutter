import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../models/subscription.dart';

/// Интервал подписки (как в веб).
typedef SubscriptionInterval = String; // 'monthly' | 'annual'

class SubscriptionApiService {
  /// GET /subscriptions/current — текущая подписка владельца.
  static Future<Subscription?> getCurrent(String accessToken) async {
    try {
      final body = await ApiClient.get('/subscriptions/current', accessToken);
      if (body is! Map<String, dynamic>) return null;
      return Subscription.fromJson(body);
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] getCurrent: $e');
      return null;
    }
  }

  /// GET /subscriptions/invoices — список счетов.
  static Future<List<SubscriptionInvoice>> getInvoices(
    String accessToken,
  ) async {
    try {
      final body = await ApiClient.get('/subscriptions/invoices', accessToken);
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
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] getInvoices: $e');
      return [];
    }
  }

  /// POST /subscriptions/create-checkout-session — URL для оплаты.
  static Future<String?> createCheckoutSession(
    String accessToken,
    SubscriptionInterval interval,
  ) async {
    try {
      final body =
          await ApiClient.post(
                '/subscriptions/create-checkout-session',
                accessToken,
                body: {'interval': interval},
              )
              as Map<String, dynamic>?;
      return body?['url'] as String?;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] createCheckoutSession: $e');
      rethrow;
    }
  }

  /// POST /subscriptions/create-portal-session — URL портала Stripe.
  static Future<String?> createPortalSession(String accessToken) async {
    try {
      final body =
          await ApiClient.post(
                '/subscriptions/create-portal-session',
                accessToken,
              )
              as Map<String, dynamic>?;
      return body?['url'] as String?;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] createPortalSession: $e');
      rethrow;
    }
  }

  /// POST /subscriptions/cancel — отмена в конце периода.
  static Future<bool> cancel(String accessToken) async {
    await ApiClient.post('/subscriptions/cancel', accessToken);
    return true;
  }

  /// POST /subscriptions/confirm-checkout — подтверждение после редиректа.
  static Future<bool> confirmCheckout(
    String accessToken,
    String sessionId,
  ) async {
    try {
      await ApiClient.post(
        '/subscriptions/confirm-checkout',
        accessToken,
        body: {'session_id': sessionId},
      );
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionAPI] confirmCheckout: $e');
      return false;
    }
  }
}
