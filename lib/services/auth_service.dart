import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserModel? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  /// Токен для запросов к API (Bearer).
  String? get accessToken => _supabase.auth.currentSession?.accessToken;

  /// Обновить сессию (продлить токен). Вызывать перед важными запросами.
  Future<void> refreshSession() async {
    try {
      final res = await _supabase.auth.refreshSession();
      if (res.session != null) {
        await _fetchUser(res.session!.accessToken);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] refreshSession error: $e');
      rethrow;
    }
  }

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _fetchUser(session.accessToken);
      } else {
        _user = null;
        _isAuthenticated = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auth init error: $e');
      }
      _user = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Загружает пользователя из API по токену. Возвращает текст ошибки при неудаче.
  Future<String?> _fetchUser(String accessToken) async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/auth/user');
      if (kDebugMode) {
        debugPrint('[Auth] GET ${url.toString()}');
      }
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $accessToken',
        },
      );
      if (kDebugMode) {
        debugPrint('[Auth] /auth/user status=${response.statusCode} body=${response.body.length} chars');
      }
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData == null) {
          if (kDebugMode) debugPrint('[Auth] Response 200 but no "user" in body');
          _user = null;
          _isAuthenticated = false;
          return 'В ответе API нет поля user';
        }
        _user = UserModel.fromJson(userData);
        _isAuthenticated = _user != null;
        if (kDebugMode) debugPrint('[Auth] User loaded: ${_user?.email} role=${_user?.role}');
        return null;
      }
      _user = null;
      _isAuthenticated = false;
      String msg = 'Ошибка ${response.statusCode}';
      try {
        final err = json.decode(response.body) as Map<String, dynamic>?;
        if (err != null && err['message'] != null) {
          msg = err['message'] as String;
        }
      } catch (_) {}
      if (kDebugMode) debugPrint('[Auth] /auth/user failed: $msg');
      return msg;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Auth] Fetch user error: $e');
        debugPrint('[Auth] Stack: $st');
      }
      _user = null;
      _isAuthenticated = false;
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Failed host lookup') ||
          errStr.contains('NetworkException')) {
        return 'Нет связи с сервером. Проверьте EXPO_PUBLIC_API_URL в .env и что бекенд запущен.';
      }
      return errStr;
    }
  }

  /// Вход через Google (нативный), затем получение пользователя из API.
  Future<({bool success, String? error})> loginWithGoogle() async {
    final webClientId = AppConfig.googleWebClientId;
    if (webClientId.isEmpty) {
      return (success: false, error: 'Google Web Client ID не настроен');
    }
    if (kDebugMode) debugPrint('[Auth] loginWithGoogle: start');
    try {
      _isLoading = true;
      notifyListeners();

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        clientId: Platform.isIOS ? AppConfig.googleIosClientId : null,
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        if (kDebugMode) debugPrint('[Auth] Google sign in cancelled');
        _isLoading = false;
        notifyListeners();
        return (success: false, error: 'Вход отменён');
      }
      if (kDebugMode) debugPrint('[Auth] Google account: ${account.email}');
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null) {
        _isLoading = false;
        notifyListeners();
        return (success: false, error: 'Нет ID токена от Google');
      }
      if (kDebugMode) debugPrint('[Auth] Got idToken, calling Supabase signInWithIdToken');

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final session = _supabase.auth.currentSession;
      if (session == null) {
        if (kDebugMode) debugPrint('[Auth] No session after signInWithIdToken');
        _isLoading = false;
        notifyListeners();
        return (success: false, error: 'Нет сессии после входа');
      }
      if (kDebugMode) debugPrint('[Auth] Session OK, fetching user from API');

      final fetchError = await _fetchUser(session.accessToken);
      _isLoading = false;
      notifyListeners();

      if (!_isAuthenticated || _user == null) {
        return (success: false, error: fetchError ?? 'Пользователь не найден в системе');
      }
      return (success: true, error: null);
    } catch (e) {
      _user = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      String msg = e is AuthException ? e.message : e.toString();
      if (kDebugMode) debugPrint('[Auth] loginWithGoogle exception: $e');
      // ApiException: 10 = DEVELOPER_ERROR — в Google Cloud не добавлен SHA-1 для Android
      if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
        msg =
            'Ошибка Google (10): добавьте SHA-1 в Google Cloud. В папке android выполните: '
            'gradlew signingReport. Скопируйте SHA-1 в Google Cloud → Credentials → Android client (com.example.mobile).';
      }
      return (success: false, error: msg);
    }
  }

  /// Логин через Supabase, затем получение пользователя из API.
  Future<({bool success, String? error})> login(
    String email,
    String password,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.session == null) {
        _isLoading = false;
        notifyListeners();
        return (success: false, error: 'Нет сессии');
      }

      final fetchError = await _fetchUser(response.session!.accessToken);
      _isLoading = false;
      notifyListeners();

      if (!_isAuthenticated || _user == null) {
        return (success: false, error: fetchError ?? 'Пользователь не найден');
      }
      return (success: true, error: null);
    } catch (e) {
      _user = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      final msg = e is AuthException ? e.message : e.toString();
      return (success: false, error: msg);
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Обновляет профиль (имя, телефон) через PUT /auth/profile.
  Future<({bool success, String? error})> updateProfile({
    required String name,
    required String phone,
  }) async {
    final token = accessToken;
    if (token == null) {
      return (success: false, error: 'Нет сессии');
    }
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/auth/profile');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $token',
        },
        body: json.encode({'name': name.trim(), 'phone': phone.trim()}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          _user = UserModel.fromJson(userData);
          notifyListeners();
        }
        return (success: true, error: null);
      }
      String msg = 'Ошибка ${response.statusCode}';
      try {
        final err = json.decode(response.body) as Map<String, dynamic>?;
        if (err != null && err['message'] != null) {
          msg = err['message'] as String;
        }
      } catch (_) {}
      return (success: false, error: msg);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Меняет пароль через Supabase updateUser.
  Future<({bool success, String? error})> updatePassword(String newPassword) async {
    try {
      final res = await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (res.user != null) return (success: true, error: null);
      return (success: false, error: 'Не удалось обновить пароль');
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Удаляет аккаунт через DELETE /auth/account, затем выходит.
  Future<({bool success, String? error})> deleteAccount() async {
    final token = accessToken;
    if (token == null) {
      return (success: false, error: 'Нет сессии');
    }
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/auth/account');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await logout();
        return (success: true, error: null);
      }
      String msg = 'Ошибка ${response.statusCode}';
      try {
        final err = json.decode(response.body) as Map<String, dynamic>?;
        if (err != null && err['message'] != null) {
          msg = err['message'] as String;
        }
      } catch (_) {}
      return (success: false, error: msg);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
}
