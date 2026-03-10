import 'package:flutter/foundation.dart';

import '../../models/salon.dart';
import '../dashboard_api_service.dart';

/// In-memory cache for current salon. TTL 3 minutes; invalidate on update/create/logout.
class SalonCache extends ChangeNotifier {
  Salon? _salon;
  String? _tokenHint;
  DateTime? _fetchedAt;
  static const _ttl = Duration(minutes: 3);

  Salon? get salon => _salon;

  bool get isStale {
    if (_fetchedAt == null) return true;
    return DateTime.now().difference(_fetchedAt!) > _ttl;
  }

  /// Returns cached salon if valid for this token and not stale; otherwise fetches.
  Future<Salon?> getSalon(String? accessToken) async {
    if (accessToken == null || accessToken.isEmpty) {
      _clear();
      return null;
    }
    if (_salon != null && _tokenHint == accessToken && !isStale) {
      return _salon;
    }
    try {
      final s = await DashboardApiService.getCurrentSalon(accessToken);
      if (s != null) {
        _salon = s;
        _tokenHint = accessToken;
        _fetchedAt = DateTime.now();
        notifyListeners();
      } else {
        _clear();
      }
      return _salon;
    } catch (_) {
      rethrow;
    }
  }

  /// Call after updateCurrentSalon or createCurrentSalon success to refetch.
  void invalidate() {
    _clear();
    notifyListeners();
  }

  void _clear() {
    _salon = null;
    _tokenHint = null;
    _fetchedAt = null;
  }
}
