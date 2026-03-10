class Salon {
  final String id;
  final String? name;
  final String? description;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? instagram;
  final List<String>? photos;
  final Map<String, dynamic>? workingHours;
  final Map<String, dynamic>? reminderSettings;
  final String? slug;
  final bool? autoConfirmBookings;
  final double? latitude;
  final double? longitude;

  Salon({
    required this.id,
    this.name,
    this.description,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.instagram,
    this.photos,
    this.workingHours,
    this.reminderSettings,
    this.slug,
    this.autoConfirmBookings,
    this.latitude,
    this.longitude,
  });

  factory Salon.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null) throw ArgumentError('Salon id is required');
    List<String>? photosList;
    final p = json['photos'];
    if (p is List) {
      photosList = p.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    Map<String, dynamic>? wh;
    final whRaw = json['workingHours'];
    if (whRaw is Map) {
      wh = Map<String, dynamic>.from(whRaw);
    }
    Map<String, dynamic>? rs;
    final rsRaw = json['reminderSettings'];
    if (rsRaw is Map) {
      rs = Map<String, dynamic>.from(rsRaw);
    }
    double? lat;
    final latVal = json['latitude'];
    if (latVal != null) lat = (latVal is num) ? latVal.toDouble() : double.tryParse(latVal.toString());
    double? lon;
    final lonVal = json['longitude'];
    if (lonVal != null) lon = (lonVal is num) ? lonVal.toDouble() : double.tryParse(lonVal.toString());
    return Salon(
      id: id.toString(),
      name: json['name'] as String?,
      description: json['description'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      instagram: json['instagram'] as String?,
      photos: photosList,
      workingHours: wh,
      reminderSettings: rs,
      slug: json['slug'] as String?,
      autoConfirmBookings: json['autoConfirmBookings'] as bool?,
      latitude: lat,
      longitude: lon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'instagram': instagram,
      'photos': photos,
      'workingHours': workingHours,
      'reminderSettings': reminderSettings,
      'slug': slug,
      'autoConfirmBookings': autoConfirmBookings,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Payload for PUT /salons/current (only updatable fields).
  Map<String, dynamic> toUpdatePayload() {
    return {
      if (name != null) 'name': name,
      if (autoConfirmBookings != null) 'autoConfirmBookings': autoConfirmBookings,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (website != null) 'website': website,
      if (instagram != null) 'instagram': instagram,
      if (photos != null) 'photos': photos,
      if (workingHours != null) 'workingHours': workingHours,
      if (reminderSettings != null) 'reminderSettings': reminderSettings,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
