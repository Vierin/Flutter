class Salon {
  final String id;
  final String? name;
  final String? address;

  Salon({
    required this.id,
    this.name,
    this.address,
  });

  factory Salon.fromJson(Map<String, dynamic> json) {
    return Salon(
      id: json['id'] as String,
      name: json['name'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
    };
  }
}


