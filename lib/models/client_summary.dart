/// Summary of a client derived from bookings (deduplicated by key).
class ClientSummary {
  const ClientSummary({
    required this.key,
    required this.name,
    this.email,
    this.phone,
    required this.lastVisit,
    required this.isSleeper,
  });

  final String key;
  final String name;
  final String? email;
  final String? phone;
  final DateTime lastVisit;
  final bool isSleeper;
}
