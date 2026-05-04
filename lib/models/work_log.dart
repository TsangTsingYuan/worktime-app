class WorkLog {
  final int? id;
  final int userId;
  final String title;
  final String category;
  final int startTime;
  final int? endTime;
  final int duration;
  final int status; // 0: ongoing, 1: completed
  final String notes;

  WorkLog({
    this.id,
    required this.userId,
    required this.title,
    this.category = '',
    required this.startTime,
    this.endTime,
    this.duration = 0,
    this.status = 0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'category': category,
        'startTime': startTime,
        'endTime': endTime,
        'duration': duration,
        'status': status,
        'notes': notes,
      };

  factory WorkLog.fromMap(Map<String, dynamic> map) => WorkLog(
        id: map['id'],
        userId: map['userId'],
        title: map['title'] ?? '',
        category: map['category'] ?? '',
        startTime: map['startTime'],
        endTime: map['endTime'],
        duration: map['duration'] ?? 0,
        status: map['status'] ?? 0,
        notes: map['notes'] ?? '',
      );

  WorkLog copyWith({
    int? id,
    int? userId,
    String? title,
    String? category,
    int? startTime,
    int? endTime,
    int? duration,
    int? status,
    String? notes,
  }) =>
      WorkLog(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        category: category ?? this.category,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        duration: duration ?? this.duration,
        status: status ?? this.status,
        notes: notes ?? this.notes,
      );
}
