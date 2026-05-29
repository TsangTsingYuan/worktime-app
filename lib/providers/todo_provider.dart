import 'package:flutter/foundation.dart';
import '../models/todo_item.dart';
import '../services/database_helper.dart';

class TodoProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<TodoItem> _todos = [];
  final Map<int, List<TodoItem>> _subtaskCache = {};
  bool _loading = false;

  List<TodoItem> get todos => _todos;
  bool get loading => _loading;

  // ─── Calendar month tracking ───

  int selectedYear = 0;
  int selectedMonth = 0;

  // ─── Load todos for a date range ───

  Future<void> loadTodos(int userId,
      {int? startDay, int? endDay, int? statusFilter, int? priorityFilter, String? categoryFilter, String? searchQuery}) async {
    _loading = true;
    notifyListeners();
    _todos = await _db.getTodos(userId,
        startDay: startDay,
        endDay: endDay,
        statusFilter: statusFilter,
        priorityFilter: priorityFilter,
        categoryFilter: categoryFilter,
        searchQuery: searchQuery);
    _loading = false;
    notifyListeners();
  }

  /// Load todos for an entire month (for calendar markers)
  Future<Set<DateTime>> getTodoDates(
      int userId, int year, int month) async {
    final startMs =
        DateTime(year, month, 1).millisecondsSinceEpoch;
    final endMs = DateTime(year, month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;
    final todos = await _db.getTodosByDateRange(userId, startMs, endMs);
    return todos
        .where((t) => t.dueDate != null)
        .map((t) {
          final dt = DateTime.fromMillisecondsSinceEpoch(t.dueDate!);
          return DateTime(dt.year, dt.month, dt.day);
        })
        .toSet();
  }

  // ─── CRUD ───

  Future<int> addTodo(TodoItem todo) async {
    final id = await _db.insertTodo(todo);
    _todos.insert(0, todo.copyWith(id: id));
    notifyListeners();
    return id;
  }

  Future<void> updateTodo(TodoItem todo) async {
    await _db.updateTodo(todo);
    final idx = _todos.indexWhere((t) => t.id == todo.id);
    if (idx >= 0) _todos[idx] = todo;
    notifyListeners();
  }

  Future<void> deleteTodo(int id) async {
    await _db.deleteTodo(id);
    _todos.removeWhere((t) => t.id == id || t.parentId == id);
    _subtaskCache.remove(id);
    notifyListeners();
  }

  Future<void> toggleComplete(TodoItem todo) async {
    final newStatus = todo.status == 2 ? 0 : 2;
    final updated = todo.copyWith(status: newStatus);
    await _db.updateTodo(updated);
    final idx = _todos.indexWhere((t) => t.id == todo.id);
    if (idx >= 0) _todos[idx] = updated;

    // Handle recurring: if completed and has recurring rule, generate next
    if (newStatus == 2 && todo.recurringRule.isNotEmpty) {
      _generateRecurring(todo);
    }

    notifyListeners();
  }

  // ─── Subtasks ───

  Future<List<TodoItem>> loadSubtasks(int parentId) async {
    final subtasks = await _db.getSubtasks(parentId);
    _subtaskCache[parentId] = subtasks;
    return subtasks;
  }

  List<TodoItem>? getCachedSubtasks(int parentId) =>
      _subtaskCache[parentId];

  Future<int> addSubtask(int parentId, String title) async {
    final parent = _todos.firstWhere(
      (t) => t.id == parentId,
      orElse: () => _todos.first,
    );
    final id = await _db.insertTodo(TodoItem(
      userId: parent.userId,
      title: title,
      parentId: parentId,
      status: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    // Invalidate cache
    _subtaskCache.remove(parentId);
    notifyListeners();
    return id;
  }

  Future<void> toggleSubtask(TodoItem subtask) async {
    await toggleComplete(subtask);
    _subtaskCache.remove(subtask.parentId);
    notifyListeners();
  }

  // ─── Recurring tasks ───

  void _generateRecurring(TodoItem completed) {
    final now = DateTime.now();
    DateTime nextDue;

    switch (completed.recurringRule) {
      case 'daily':
        nextDue = DateTime(now.year, now.month, now.day + 1);
        break;
      case 'weekly':
        nextDue = DateTime(now.year, now.month, now.day + 7);
        break;
      case 'monthly':
        nextDue = DateTime(now.year, now.month + 1, now.day);
        break;
      default:
        return;
    }

    _db.insertTodo(TodoItem(
      userId: completed.userId,
      title: completed.title,
      description: completed.description,
      priority: completed.priority,
      category: completed.category,
      dueDate: nextDue.millisecondsSinceEpoch,
      recurringRule: completed.recurringRule,
      sortOrder: completed.sortOrder,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ));
  }

  // ─── Stats ───

  Future<int> getCompletedCount(int userId, int startMs, int endMs) async {
    return _db.getCompletedCount(userId, startMs, endMs);
  }

  /// Stats grouped by date for a range
  Future<Map<DateTime, int>> getDailyCompletedCounts(
      int userId, int startMs, int endMs) async {
    final todos = await _db.getTodos(userId);
    final result = <DateTime, int>{};
    for (final t in todos) {
      if (t.status == 2 &&
          t.updatedAt >= startMs &&
          t.updatedAt <= endMs) {
        final d = DateTime.fromMillisecondsSinceEpoch(t.updatedAt);
        final key = DateTime(d.year, d.month, d.day);
        result[key] = (result[key] ?? 0) + 1;
      }
    }
    return result;
  }

  // ─── 开始执行 ───

  /// 标记待办为"进行中"，返回其信息供计时使用
  Future<TodoItem> startExecution(TodoItem todo) async {
    final updated = todo.copyWith(status: 1);
    await _db.updateTodo(updated);
    final idx = _todos.indexWhere((t) => t.id == todo.id);
    if (idx >= 0) _todos[idx] = updated;
    notifyListeners();
    return updated;
  }

  /// 结束计时时回调：标记待办为完成
  Future<void> completeOnTimerEnd(TodoItem todo, int workLogId) async {
    final updated = todo.copyWith(
      status: 2,
      linkedWorkLogId: workLogId,
    );
    await _db.updateTodo(updated);
    final idx = _todos.indexWhere((t) => t.id == todo.id);
    if (idx >= 0) _todos[idx] = updated;

    // Handle recurring
    if (todo.recurringRule.isNotEmpty) {
      _generateRecurring(todo);
    }

    notifyListeners();
  }

  // ─── 提醒检测 ───

  /// 检测即将开始的待办（开始时间前N分钟）
  /// 返回需要提醒的待办列表
  List<TodoItem> checkStartReminders() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <TodoItem>[];
    for (final todo in _todos) {
      if (todo.status != 0) continue; // 只提醒待办状态
      if (todo.startTime == null || todo.reminderBeforeStart <= 0) continue;
      final remindAt = todo.startTime! - todo.reminderBeforeStart * 60 * 1000;
      if (now >= remindAt && now < todo.startTime!) {
        result.add(todo);
      }
    }
    return result;
  }

  /// 检测即将截止的待办（截止时间前N分钟）
  List<TodoItem> checkEndReminders() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <TodoItem>[];
    for (final todo in _todos) {
      if (todo.status != 0) continue;
      if (todo.dueDate == null || todo.reminderBeforeEnd <= 0) continue;
      final remindAt = todo.dueDate! - todo.reminderBeforeEnd * 60 * 1000;
      if (now >= remindAt && now < todo.dueDate!) {
        result.add(todo);
      }
    }
    return result;
  }

  /// 检测已过期待办，仅对未通知过的弹出一次提示
  /// 返回需要通知的待办列表，并标记 notified
  Future<List<TodoItem>> checkOverdueAndMark() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final overdue = <TodoItem>[];
    for (final todo in _todos) {
      if (todo.status != 0) continue;
      if (todo.dueDate == null || todo.dueDate! >= now) continue;
      if (todo.overdueNotified) continue;
      overdue.add(todo);
      // 标记已通知
      final marked = todo.copyWith(overdueNotified: true);
      await _db.updateTodo(marked);
      final idx = _todos.indexWhere((t) => t.id == todo.id);
      if (idx >= 0) _todos[idx] = marked;
    }
    if (overdue.isNotEmpty) notifyListeners();
    return overdue;
  }
}
