class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, String> data;
  final bool read;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    Map<String, String>? data,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'data': data,
    'read': read,
  };

  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      data:
          (json['data'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString() ?? ''),
          ) ??
          {},
      read: json['read'] as bool? ?? false,
    );
  }
}
