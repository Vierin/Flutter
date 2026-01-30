/// Блокировка времени: выходной, занятость или закрытие салона.
enum TimeBlockType {
  timeOff,
  busy,
  closure,
}

class TimeBlock {
  final String id;
  final String salonId;
  final String? staffId;
  final TimeBlockType type;
  final String? reason;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;

  TimeBlock({
    required this.id,
    required this.salonId,
    this.staffId,
    required this.type,
    this.reason,
    required this.startDate,
    required this.endDate,
    this.notes,
  });

  static TimeBlockType _typeFromString(String? v) {
    switch (v?.toUpperCase()) {
      case 'TIME_OFF':
        return TimeBlockType.timeOff;
      case 'BUSY':
        return TimeBlockType.busy;
      case 'CLOSURE':
        return TimeBlockType.closure;
      default:
        return TimeBlockType.timeOff;
    }
  }

  factory TimeBlock.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) throw ArgumentError('TimeBlock id is required');
    final salonId = json['salonId']?.toString() ?? '';
    final startRaw = json['startDate'];
    final endRaw = json['endDate'];
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    if (startRaw is String) startDate = DateTime.parse(startRaw);
    if (endRaw is String) endDate = DateTime.parse(endRaw);
    return TimeBlock(
      id: id,
      salonId: salonId,
      staffId: json['staffId']?.toString(),
      type: _typeFromString(json['type'] as String?),
      reason: json['reason'] as String?,
      startDate: startDate,
      endDate: endDate,
      notes: json['notes'] as String?,
    );
  }
}
