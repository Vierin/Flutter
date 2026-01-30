/// Услуга салона для экрана «Сервисы».
class ServiceItem {
  final String id;
  final String name;
  final String? description;
  final String? nameEn;
  final String? nameVi;
  final String? nameRu;
  final double? price;
  final int? duration;
  final String? salonId;
  /// Название категории (из service_categories) для тега.
  final String? categoryName;
  /// Название группы (из serviceGroup) для тега.
  final String? groupName;

  ServiceItem({
    required this.id,
    required this.name,
    this.description,
    this.nameEn,
    this.nameVi,
    this.nameRu,
    this.price,
    this.duration,
    this.salonId,
    this.categoryName,
    this.groupName,
  });

  String get displayName => name;

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Теги для отображения (категория и группа как пилюли).
  List<String> get tagNames {
    final list = <String>[];
    if (categoryName != null && categoryName!.isNotEmpty) list.add(categoryName!);
    if (groupName != null && groupName!.isNotEmpty && groupName != categoryName) list.add(groupName!);
    return list;
  }

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = (idRaw == null ? '' : idRaw.toString()).trim();
    final name = (json['name'] as String?) ??
        (json['nameEn'] as String?) ??
        (json['nameVi'] as String?) ??
        (json['nameRu'] as String?) ??
        '';
    String? categoryName;
    final cat = json['service_categories'];
    if (cat is Map) {
      categoryName = (cat['name_ru'] as String?) ?? (cat['name_en'] as String?) ?? (cat['name_vn'] as String?);
    }
    String? groupName;
    final gr = json['serviceGroup'];
    if (gr is Map) {
      groupName = (gr['nameRu'] as String?) ?? (gr['name'] as String?) ?? (gr['nameEn'] as String?) ?? (gr['nameVi'] as String?);
    }
    return ServiceItem(
      id: id,
      name: name,
      description: json['description'] as String?,
      nameEn: json['nameEn'] as String?,
      nameVi: json['nameVi'] as String?,
      nameRu: json['nameRu'] as String?,
      price: _parseDouble(json['price']),
      duration: _parseInt(json['duration']),
      salonId: json['salonId'] as String?,
      categoryName: categoryName,
      groupName: groupName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'nameEn': nameEn,
      'nameVi': nameVi,
      'nameRu': nameRu,
      'price': price,
      'duration': duration,
      'salonId': salonId,
      'categoryName': categoryName,
      'groupName': groupName,
    };
  }
}
