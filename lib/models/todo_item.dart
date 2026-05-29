class TodoItem {
  final int? id;
  final int userId;
  final String title;
  final String description;
  final int priority; // 0=低, 1=中, 2=高
  final int status; // 0=待办, 1=进行中, 2=已完成
  final int? dueDate; // 截止时间 epoch ms
  final int? startTime; // 计划开始时间 epoch ms
  final int reminderBeforeStart; // 开始前N分钟提醒(0=不提醒)
  final int reminderBeforeEnd; // 截止前N分钟提醒(0=不提醒)
  final bool overdueNotified; // 是否已弹出过期通知
  final String category;
  final int? linkedWorkLogId;
  final int? parentId; // 子任务指向父待办
  final String recurringRule; // '', 'daily', 'weekly', 'monthly'
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final bool isSynced;

  TodoItem({
    this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.priority = 1,
    this.status = 0,
    this.dueDate,
    this.startTime,
    this.reminderBeforeStart = 0,
    this.reminderBeforeEnd = 0,
    this.overdueNotified = false,
    this.category = '',
    this.linkedWorkLogId,
    this.parentId,
    this.recurringRule = '',
    this.sortOrder = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'dueDate': dueDate,
        'startTime': startTime,
        'reminderBeforeStart': reminderBeforeStart,
        'reminderBeforeEnd': reminderBeforeEnd,
        'overdueNotified': overdueNotified ? 1 : 0,
        'category': category,
        'linkedWorkLogId': linkedWorkLogId,
        'parentId': parentId,
        'recurringRule': recurringRule,
        'sortOrder': sortOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isSynced': isSynced ? 1 : 0,
      };

  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(
        id: map['id'],
        userId: map['userId'],
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        priority: map['priority'] ?? 1,
        status: map['status'] ?? 0,
        dueDate: map['dueDate'],
        startTime: map['startTime'],
        reminderBeforeStart: map['reminderBeforeStart'] ?? 0,
        reminderBeforeEnd: map['reminderBeforeEnd'] ?? 0,
        overdueNotified: (map['overdueNotified'] ?? 0) == 1,
        category: map['category'] ?? '',
        linkedWorkLogId: map['linkedWorkLogId'],
        parentId: map['parentId'],
        recurringRule: map['recurringRule'] ?? '',
        sortOrder: map['sortOrder'] ?? 0,
        createdAt: map['createdAt'] ?? 0,
        updatedAt: map['updatedAt'] ?? 0,
        isSynced: (map['isSynced'] ?? 0) == 1,
      );

  TodoItem copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    int? priority,
    int? status,
    int? dueDate,
    int? startTime,
    int? reminderBeforeStart,
    int? reminderBeforeEnd,
    bool? overdueNotified,
    String? category,
    int? linkedWorkLogId,
    int? parentId,
    String? recurringRule,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    bool? isSynced,
  }) =>
      TodoItem(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        dueDate: dueDate ?? this.dueDate,
        startTime: startTime ?? this.startTime,
        reminderBeforeStart: reminderBeforeStart ?? this.reminderBeforeStart,
        reminderBeforeEnd: reminderBeforeEnd ?? this.reminderBeforeEnd,
        overdueNotified: overdueNotified ?? this.overdueNotified,
        category: category ?? this.category,
        linkedWorkLogId: linkedWorkLogId ?? this.linkedWorkLogId,
        parentId: parentId ?? this.parentId,
        recurringRule: recurringRule ?? this.recurringRule,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
      );

  /// 判断是否在某个日期（基于 dueDate 的年月日）
  bool isOnDate(DateTime date) {
    if (dueDate == null) return false;
    final d = DateTime.fromMillisecondsSinceEpoch(dueDate!);
    return d.year == date.year && d.month == date.month && d.day == date.day;
  }

  /// 判断是否已过期（过了 dueDate 且未完成）
  bool get isOverdue =>
      dueDate != null &&
      status != 2 &&
      DateTime.fromMillisecondsSinceEpoch(dueDate!)
          .isBefore(DateTime.now());

  String get priorityLabel => ['低', '中', '高'][priority.clamp(0, 2)];
  String get statusLabel => ['待办', '进行中', '已完成'][status.clamp(0, 2)];
}
