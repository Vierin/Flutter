import 'package:flutter/foundation.dart';

import '../../models/booking.dart';
import '../dashboard_api_service.dart';

/// In-memory cache for owner bookings. TTL 2 minutes; invalidate on create/confirm/cancel/reject/update.
class BookingsCache extends ChangeNotifier {
  List<Booking>? _bookings;
  String? _tokenHint;
  DateTime? _fetchedAt;
  static const _ttl = Duration(minutes: 2);

  List<Booking>? get bookings => _bookings;

  bool get isStale {
    if (_fetchedAt == null) return true;
    return DateTime.now().difference(_fetchedAt!) > _ttl;
  }

  /// Returns cached bookings if valid for this token and not stale; otherwise fetches.
  Future<List<Booking>> getBookings(String? accessToken) async {
    if (accessToken == null || accessToken.isEmpty) {
      _clear();
      return [];
    }
    if (_bookings != null && _tokenHint == accessToken && !isStale) {
      return _bookings!;
    }
    try {
      final list = await DashboardApiService.getOwnerBookings(accessToken);
      _bookings = list;
      _tokenHint = accessToken;
      _fetchedAt = DateTime.now();
      notifyListeners();
      return list;
    } catch (_) {
      rethrow;
    }
  }

  /// Call after any booking mutation (create, confirm, cancel, reject, update).
  void invalidate() {
    _clear();
    notifyListeners();
  }

  void _clear() {
    _bookings = null;
    _tokenHint = null;
    _fetchedAt = null;
  }
}
