import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locales.dart';

/// Loads and caches translations from assets/l10n/{locale}/app.json.
/// Use t('key') or t('section.key') for nested keys. Returns key if missing.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    _loadSavedLocale();
  }

  String _localeCode = defaultLocaleCode;
  Map<String, dynamic> _strings = {};
  bool _loaded = false;

  String get localeCode => _localeCode;
  bool get isLoaded => _loaded;

  /// Current locale for MaterialApp (e.g. Locale('ru', 'RU')).
  String get languageTag {
    if (_localeCode == 'en') return 'en';
    if (_localeCode == 'vi') return 'vi';
    return 'ru';
  }

  static const _prefsKey = 'app_locale';

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && supportedLocaleCodes.contains(saved)) {
        _localeCode = saved;
      }
    } catch (_) {}
    await loadStrings();
  }

  /// Load app.json for current locale. Call after setLocale.
  Future<void> loadStrings() async {
    try {
      final key = 'assets/l10n/$_localeCode/app.json';
      final data = await rootBundle.loadString(key);
      final decoded = json.decode(data) as Map<String, dynamic>?;
      _strings = decoded ?? {};
      _loaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[LocaleProvider] loadStrings: $e');
      _strings = {};
      _loaded = true;
    }
    notifyListeners();
  }

  /// Set locale and reload strings. Persists to SharedPreferences.
  Future<void> setLocale(String code) async {
    if (!supportedLocaleCodes.contains(code) || code == _localeCode) return;
    _localeCode = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
    await loadStrings();
  }

  /// Get translation by key. Supports nested keys: t('nav.dashboard') -> map['nav']['dashboard'].
  /// Returns [key] if not found.
  String t(String key) {
    if (key.isEmpty) return key;
    final parts = key.split('.');
    dynamic current = _strings;
    for (final part in parts) {
      if (current is! Map<String, dynamic>) return key;
      current = current[part];
    }
    if (current is String) return current;
    return key;
  }

  /// Get list of strings by key (e.g. calendar.months). Returns empty list if not found.
  List<String> tList(String key) {
    if (key.isEmpty) return [];
    final parts = key.split('.');
    dynamic current = _strings;
    for (final part in parts) {
      if (current is! Map<String, dynamic>) return [];
      current = current[part];
    }
    if (current is List) {
      return current.map((e) => e?.toString() ?? '').toList();
    }
    return [];
  }
}
