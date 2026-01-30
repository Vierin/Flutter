/// Сотрудник салона для экрана «Персонал».
class StaffMember {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String salonId;
  final String? accessLevel;

  StaffMember({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.salonId,
    this.accessLevel,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw == null ? '' : idRaw.toString();
    final salonIdRaw = json['salonId'];
    final salonId = salonIdRaw == null ? '' : salonIdRaw.toString();
    return StaffMember(
      id: id,
      name: (json['name'] as String?) ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      salonId: salonId,
      accessLevel: json['accessLevel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'salonId': salonId,
      'accessLevel': accessLevel,
    };
  }
}
