import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_client.dart';

/// Handles FCM token registration with backend and in-app message handling.
class PushNotificationService {
  PushNotificationService._();

  static const String _tag = '[Push]';

  static void _log(String msg) {
    // Always log in debug; use tag so logcat can filter: adb logcat -s "flutter"
    debugPrint('$_tag $msg');
  }

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'henzo_default',
    'Henzo',
    description: 'Уведомления приложения Henzo',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Called when a notification is received (foreground) or app opened from notification.
  static void Function(String title, String body, Map<String, String> data)? onNotificationReceived;

  /// Initialize: request permission, get token, set up message handlers.
  /// [onNotificationReceived] is called for each received message so the app can show them in the notifications screen.
  static Future<void> initialize({
    void Function(String title, String body, Map<String, String> data)? onNotificationReceived,
  }) async {
    PushNotificationService.onNotificationReceived = onNotificationReceived;
    _log('initialize start');
    try {
      final androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final initSettings = InitializationSettings(
        android: androidInit,
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _log('local notifications initialized');
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(_channel);
        _log('Android channel henzo_default created');
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _log('initialMessage: ${initial.notification?.title}');
        _notifyReceived(
          initial.notification?.title ?? 'Henzo',
          initial.notification?.body ?? '',
          _dataToStringMap(initial.data),
        );
        _onMessageOpenedApp(initial);
      }
      _log('initialize done');
    } catch (e, st) {
      _log('initialize error: $e');
      if (kDebugMode) debugPrint(st.toString());
    }
  }

  /// Call when user enters the app (e.g. after login). Shows system permission dialog.
  static Future<bool> requestNotificationPermission() async {
    _log('requestNotificationPermission start');
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        _log('Android permission: $status');
        return status.isGranted;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _log('iOS permission: ${settings.authorizationStatus}');
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      return true;
    } catch (e) {
      _log('requestPermission error: $e');
      return false;
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    _log('notification tap: ${response.payload}');
  }

  /// Register FCM token with backend. Call after login and when language changes.
  static Future<void> registerToken({
    required String accessToken,
    required String language,
  }) async {
    _log('registerToken start');
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _log('registerToken: no token from FCM');
        return;
      }
      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      _log('registerToken: platform=$platform token=${token.length} chars');
      await ApiClient.post(
        '/notifications/push-token',
        accessToken,
        body: {
          'token': token,
          'platform': platform,
          'language': language,
        },
      );
      _log('registerToken OK: backend saved token');
      if (kDebugMode) debugPrint('$_tag FCM token (copy for test): $token');
    } on ApiException catch (e) {
      _log('registerToken API error: ${e.statusCode} ${e.message}');
    } catch (e) {
      _log('registerToken error: $e');
    }
  }

  static Map<String, String> _dataToStringMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return {};
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  static void _notifyReceived(String title, String body, Map<String, String> data) {
    try {
      onNotificationReceived?.call(title, body, data);
    } catch (_) {}
  }

  static void _onForegroundMessage(RemoteMessage message) {
    _log('onMessage (foreground): title=${message.notification?.title} body=${message.notification?.body}');
    final title = message.notification?.title ?? 'Henzo';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) {
      _log('onMessage: skip show (no title/body)');
      return;
    }
    _notifyReceived(title, body, _dataToStringMap(message.data));
    _log('onMessage: showing local notification');
    _showLocalNotification(
      id: message.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  static Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'henzo_default',
        'Henzo',
        channelDescription: 'Уведомления приложения Henzo',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    try {
      await _localNotifications.show(id, title, body, details, payload: payload);
      _log('local notification shown: $title');
    } catch (e) {
      _log('local notification show error: $e');
    }
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _log('onMessageOpenedApp: ${message.data}');
    _notifyReceived(
      message.notification?.title ?? 'Henzo',
      message.notification?.body ?? '',
      _dataToStringMap(message.data),
    );
  }
}
