import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

const String _keyList = 'henzo_notifications_list';

class NotificationsStore extends ChangeNotifier {
  NotificationsStore() : _items = [];

  List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((e) => !e.read).length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyList);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map(
              (e) =>
                  AppNotification.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        _items = list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _items = [];
      }
    } catch (_) {
      _items = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _items.map((e) => e.toJson()).toList();
      await prefs.setString(_keyList, jsonEncode(encoded));
    } catch (_) {}
  }

  void addFromPush(String title, String body, Map<String, String> data) {
    if (title.isEmpty && body.isEmpty) return;
    final id = '${DateTime.now().millisecondsSinceEpoch}_${data.hashCode}';
    _items.insert(
      0,
      AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        data: data,
        read: false,
      ),
    );
    _save();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    bool changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  void markRead(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true);
      _save();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    _items = [];
    await _save();
    notifyListeners();
  }
}
