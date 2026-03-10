class Booking {
  final String id;
  final DateTime dateTime;
  final BookingStatus status;
  final Service? service;
  final User? user;
  final Staff? staff;
  final String? staffId;
  final String? serviceId;
  final String? notes;

  Booking({
    required this.id,
    required this.dateTime,
    required this.status,
    this.service,
    this.user,
    this.staff,
    this.staffId,
    this.serviceId,
    this.notes,
  });

  /// ID сотрудника (из staff.id или staffId в ответе API).
  String? get effectiveStaffId => staff?.id ?? staffId;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final staffIdRaw = json['staffId'];
    final staffId = staffIdRaw != null ? staffIdRaw.toString() : null;
    final serviceIdRaw = json['serviceId'];
    final serviceId = serviceIdRaw != null ? serviceIdRaw.toString() : null;
    return Booking(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      status: BookingStatus.fromString(json['status'] as String),
      service: json['service'] != null
          ? Service.fromJson(json['service'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      staff: json['staff'] != null
          ? Staff.fromJson(json['staff'] as Map<String, dynamic>)
          : null,
      staffId: staffId,
      serviceId: serviceId,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'status': status.toString(),
      'service': service?.toJson(),
      'user': user?.toJson(),
      'staff': staff?.toJson(),
      'serviceId': serviceId,
      'notes': notes,
    };
  }
}

enum BookingStatus {
  pending,
  confirmed,
  completed,
  canceled,
  noShow;

  static BookingStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return BookingStatus.pending;
      case 'CONFIRMED':
        return BookingStatus.confirmed;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'CANCELED':
      case 'CANCELLED':
        return BookingStatus.canceled;
      case 'NO_SHOW':
        return BookingStatus.noShow;
      default:
        return BookingStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case BookingStatus.pending:
        return 'PENDING';
      case BookingStatus.confirmed:
        return 'CONFIRMED';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.canceled:
        return 'CANCELED';
      case BookingStatus.noShow:
        return 'NO_SHOW';
    }
  }
}

class Service {
  final String name;
  final double? price;
  final int? duration;

  Service({
    required this.name,
    this.price,
    this.duration,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ??
        (json['nameEn'] as String?) ??
        (json['nameVi'] as String?) ??
        (json['nameRu'] as String?) ??
        '';
    return Service(
      name: name,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'duration': duration,
    };
  }
}

class User {
  final String? name;
  final String? email;
  final String? phone;

  User({
    this.name,
    this.email,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
    };
  }
}

class Staff {
  final String? id;
  final String name;

  Staff({this.id, required this.name});

  factory Staff.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw == null ? null : idRaw.toString();
    return Staff(
      id: id,
      name: json['name'] as String? ?? '—',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}


