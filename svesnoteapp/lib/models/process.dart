class Process {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String status; // 'active' or 'paused'
  final DateTime createdAt;
  final DateTime? endDate; // null for lifetime processes

  Process({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.status,
    required this.createdAt,
    this.endDate,
  });

  factory Process.fromJson(Map<String, dynamic> json) {
    return Process(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  bool get isTimeLimited => endDate != null;
  bool get isActive => status == 'active';
  bool get isExpired => endDate != null && DateTime.now().isAfter(endDate!);
}
