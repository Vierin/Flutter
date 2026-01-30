import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация приложения из переменных окружения (assets/.env).
/// Ключи соответствуют именам в .env: EXPO_PUBLIC_*.
abstract final class AppConfig {
  static String get supabaseUrl =>
      (dotenv.env['EXPO_PUBLIC_SUPABASE_URL'] ?? '').trim();

  static String get supabaseAnonKey =>
      (dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'] ?? '').trim();

  /// URL API без завершающего слэша.
  static String get apiUrl {
    final url = (dotenv.env['EXPO_PUBLIC_API_URL'] ?? '').trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Web Client ID из Google Cloud (тот же, что в Supabase → Auth → Google).
  static String get googleWebClientId =>
      (dotenv.env['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'] ?? '').trim();

  /// iOS Client ID из Google Cloud (только для iOS).
  static String get googleIosClientId =>
      (dotenv.env['EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID'] ?? '').trim();
}
