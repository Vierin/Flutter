import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'api_client.dart';

/// Handles FCM token registration with backend and in-app message handling.
class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize: request permission, get token, set up message handlers.
  static Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('[Push] Permission: ${settings.authorizationStatus}');
      }
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _onMessageOpenedApp(initial);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] initialize: $e');
    }
  }

  /// Register FCM token with backend. Call after login and when language changes.
  static Future<void> registerToken({
    required String accessToken,
    required String language,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      await ApiClient.post(
        '/notifications/push-token',
        accessToken,
        body: {
          'token': token,
          'platform': platform,
          'language': language,
        },
      );
      if (kDebugMode) debugPrint('[Push] Token registered: $platform $language');
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[Push] registerToken: $e');
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] registerToken: $e');
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[Push] onMessage: ${message.notification?.title}');
    }
    // Optionally show in-app banner or SnackBar via a global key or stream.
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[Push] onMessageOpenedApp: ${message.data}');
    }
    // Navigate by message.data e.g. data['bookingId'] -> open booking detail.
    // Requires a global navigator key or callback registered by the app.
  }
}
