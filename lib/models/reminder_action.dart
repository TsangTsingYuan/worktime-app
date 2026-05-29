/// 待办提醒动作（用于弹窗交互按钮）
class ReminderAction {
  final String type; // 'start' | 'end' | 'overdue'
  final int todoId;
  final String todoTitle;
  final int? minutes;
  final String message;

  const ReminderAction({
    required this.type,
    required this.todoId,
    required this.todoTitle,
    this.minutes,
    required this.message,
  });
}
