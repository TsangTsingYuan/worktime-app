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
  final String? serverId;
  final int createdAt;
  final int updatedAt;
  final bool isSynced;

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
    this.serverId,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.isSynced = false,
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
        'serverId': serverId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isSynced': isSynced ? 1 : 0,
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
        serverId: map['serverId'],
        createdAt: map['createdAt'] ?? 0,
        updatedAt: map['updatedAt'] ?? 0,
        isSynced: (map['isSynced'] ?? 0) == 1,
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
    String? serverId,
    int? createdAt,
    int? updatedAt,
    bool? isSynced,
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
        serverId: serverId ?? this.serverId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
      );
}
