class Entry {
  final String id;
  final String userId;
  final DateTime createdAt;
  final String? audioPath;
  final String? transcript;
  final int? durationSeconds;

  const Entry({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.audioPath,
    this.transcript,
    this.durationSeconds,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      audioPath: json['audio_path'] as String?,
      transcript: json['transcript'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'audio_path': audioPath,
      'transcript': transcript,
      'duration_seconds': durationSeconds,
    };
  }
}
