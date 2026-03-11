import 'package:flutter/foundation.dart';

import '../../models/service_item.dart';
import '../../models/staff_member.dart';
import '../services_api_service.dart';
import '../staff_api_service.dart';

/// In-memory cache for services and staff by salonId. Invalidated on create/update/delete.
class ServicesStaffCache extends ChangeNotifier {
  final Map<String, List<ServiceItem>> _servicesBySalon = {};
  final Map<String, List<StaffMember>> _staffBySalon = {};

  List<ServiceItem>? getServices(String salonId) => _servicesBySalon[salonId];
  List<StaffMember>? getStaff(String salonId) => _staffBySalon[salonId];

  Future<List<ServiceItem>> getServicesForSalon(String? accessToken, String? salonId) async {
    if (accessToken == null || accessToken.isEmpty || salonId == null || salonId.isEmpty) {
      return [];
    }
    final cached = _servicesBySalon[salonId];
    if (cached != null) return cached;
    try {
      final list = await ServicesApiService.getBySalon(accessToken, salonId);
      _servicesBySalon[salonId] = list;
      notifyListeners();
      return list;
    } catch (_) {
      rethrow;
    }
  }

  Future<List<StaffMember>> getStaffForSalon(String? accessToken, String? salonId) async {
    if (accessToken == null || accessToken.isEmpty || salonId == null || salonId.isEmpty) {
      return [];
    }
    final cached = _staffBySalon[salonId];
    if (cached != null) return cached;
    try {
      final list = await StaffApiService.getBySalon(accessToken, salonId);
      _staffBySalon[salonId] = list;
      notifyListeners();
      return list;
    } catch (_) {
      rethrow;
    }
  }

  void invalidateServices(String? salonId) {
    if (salonId != null) _servicesBySalon.remove(salonId);
    notifyListeners();
  }

  void invalidateStaff(String? salonId) {
    if (salonId != null) _staffBySalon.remove(salonId);
    notifyListeners();
  }

  void invalidateAll() {
    _servicesBySalon.clear();
    _staffBySalon.clear();
    notifyListeners();
  }
}
