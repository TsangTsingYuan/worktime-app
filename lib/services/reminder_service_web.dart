import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/work_log_provider.dart';
import '../providers/todo_provider.dart';
import '../models/reminder_action.dart';
import 'database_helper.dart';

class ReminderService extends ChangeNotifier {
  SettingsProvider? _settings;
  WorkLogProvider? _workLogProvider;
  AuthProvider? _auth;

  // visibility
  bool _isTabVisible = true;

  // sedentary
  Timer? _sedentaryTimer;
  DateTime? _lastSedentaryRemindTime;

  // off-work
  Timer? _offWorkTimer;
  DateTime? _lastOffWorkRemindDate;

  // todo due date
  Timer? _todoTimer;
  final Set<int> _notifiedTodoIds = {};

  // pending message for SnackBar
  String? _pendingMessage;
  ReminderAction? _pendingAction;
  TodoProvider? _todoProvider;

  String? get pendingMessage => _pendingMessage;
  ReminderAction? get pendingAction => _pendingAction;
  bool get isTabVisible => _isTabVisible;

  // ---- visibility ----

  void initializeVisibilityListener() {
    _isTabVisible = web.document.visibilityState == 'visible';
    web.document.addEventListener('visibilitychange', _onVisibilityChange.toJS);
  }

  void _onVisibilityChange(web.Event _) {
    _isTabVisible = web.document.visibilityState == 'visible';
  }

  // ---- lifecycle ----

  void start(SettingsProvider settings, WorkLogProvider workLogProvider, AuthProvider auth, {TodoProvider? todoProvider}) {
    _settings = settings;
    _workLogProvider = workLogProvider;
    _auth = auth;
    _todoProvider = todoProvider;
    _startSedentaryTimer();
    _startOffWorkTimer();
    _startTodoTimer();
  }

  void stop() {
    _sedentaryTimer?.cancel();
    _sedentaryTimer = null;
    _offWorkTimer?.cancel();
    _offWorkTimer = null;
    _todoTimer?.cancel();
    _todoTimer = null;
    _lastSedentaryRemindTime = null;
    _lastOffWorkRemindDate = null;
    _notifiedTodoIds.clear();
    _pendingMessage = null;
    notifyListeners();
  }

  void update(SettingsProvider settings) {
    _settings = settings;
    _startSedentaryTimer();
    _startOffWorkTimer();
  }

  void clearPendingMessage() {
    _pendingMessage = null;
    _pendingAction = null;
    notifyListeners();
  }

  // ---- sedentary reminder ----

  void _startSedentaryTimer() {
    _sedentaryTimer?.cancel();
    final interval = _settings?.settings.sedentaryReminder ?? 0;
    if (interval <= 0) return;

    _lastSedentaryRemindTime = DateTime.now();

    _sedentaryTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkSedentaryReminder();
    });
  }

  void _checkSedentaryReminder() {
    final interval = _settings?.settings.sedentaryReminder ?? 0;
    if (interval <= 0) return;

    final now = DateTime.now();
    if (_lastSedentaryRemindTime != null) {
      final elapsed = now.difference(_lastSedentaryRemindTime!).inMinutes;
      if (elapsed < interval) return;
    }

    _lastSedentaryRemindTime = now;
    _notify('您已连续工作$interval分钟，起身活动一下吧！');
  }

  // ---- off-work reminder ----

  void _startOffWorkTimer() {
    _offWorkTimer?.cancel();
    if (!(_settings?.settings.offWorkReminder ?? false)) return;

    _offWorkTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkOffWorkReminder();
    });
  }

  void _checkOffWorkReminder() {
    final s = _settings?.settings;
    if (s == null || !s.offWorkReminder) return;

    final now = DateTime.now();

    // only once per calendar day
    if (_lastOffWorkRemindDate != null) {
      final lastDay = DateTime(_lastOffWorkRemindDate!.year,
          _lastOffWorkRemindDate!.month, _lastOffWorkRemindDate!.day);
      final today = DateTime(now.year, now.month, now.day);
      if (lastDay == today) return;
    }

    // parse workEnd "HH:mm"
    final parts = s.workEnd.split(':');
    if (parts.length != 2) return;
    final endH = int.tryParse(parts[0]);
    final endM = int.tryParse(parts[1]);
    if (endH == null || endM == null) return;
    final workEndTime = DateTime(now.year, now.month, now.day, endH, endM);

    if (now.isBefore(workEndTime)) return;

    // check today's logs
    final logs = _workLogProvider?.todayLogs ?? [];
    final todayStartMs =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final hasLogs = logs.any((log) => log.startTime >= todayStartMs);

    if (!hasLogs) {
      _lastOffWorkRemindDate = now;
      _notify('已过下班时间，今天还没有打卡记录！');
    }
  }

  // ---- todo due date reminder ----

  void _startTodoTimer() {
    _todoTimer?.cancel();
    _notifiedTodoIds.clear();

    _todoTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkTodoReminder();
    });
  }

  void _checkTodoReminder() {
    final userId = _auth?.user?.id;
    if (userId == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. 过期待办单次通知（使用 overdueNotified 字段）
    DatabaseHelper().getOverdueTodos(userId).then((overdue) {
      for (final todo in overdue) {
        if (todo.id != null && !todo.overdueNotified && _notifiedTodoIds.add(todo.id!)) {
          _notifyAction(ReminderAction(
            type: 'overdue',
            todoId: todo.id!,
            todoTitle: todo.title,
            message: '待办「${todo.title}」已过截止时间！',
          ));
          // 标记已通知
          DatabaseHelper().updateTodo(todo.copyWith(overdueNotified: true));
        }
      }
    });

    // 2. 开始时间提醒、截止时间提醒（通过 TodoProvider）
    final todoProvider = _todoProvider;
    if (todoProvider == null) return;

    // 开始时间前N分钟提醒
    for (final todo in todoProvider.todos) {
      if (todo.status == 2) continue;
      if (todo.id != null && _notifiedTodoIds.contains(todo.id)) continue;

      // 开始时间提醒（仅对未开始的待办，已开始执行的跳过）
      if (todo.status == 0 && todo.startTime != null && todo.reminderBeforeStart > 0) {
        final remindAt = todo.startTime! - todo.reminderBeforeStart * 60 * 1000;
        if (now >= remindAt && now < todo.startTime! + 60000) { // 1分钟内只提醒一次
          if (todo.id != null) _notifiedTodoIds.add(todo.id!);
          _notifyAction(ReminderAction(
            type: 'start',
            todoId: todo.id!,
            todoTitle: todo.title,
            minutes: todo.reminderBeforeStart,
            message: '待办「${todo.title}」即将开始！还有${todo.reminderBeforeStart}分钟',
          ));
          continue;
        }
      }

      // 截止时间提醒
      if (todo.dueDate != null && todo.reminderBeforeEnd > 0) {
        final remindAt = todo.dueDate! - todo.reminderBeforeEnd * 60 * 1000;
        if (now >= remindAt && now < todo.dueDate! + 60000) {
          if (todo.id != null) _notifiedTodoIds.add(todo.id!);
          _notifyAction(ReminderAction(
            type: 'end',
            todoId: todo.id!,
            todoTitle: todo.title,
            minutes: todo.reminderBeforeEnd,
            message: '待办「${todo.title}」即将在${todo.reminderBeforeEnd}分钟后截止！',
          ));
        }
      }
    }
  }

  // ---- notification dispatch ----

  void _notify(String message) {
    if (_isTabVisible) {
      _pendingMessage = message;
      _pendingAction = null;
      notifyListeners();
    } else {
      _showBrowserNotification(message);
    }
  }

  void _notifyAction(ReminderAction action) {
    if (_isTabVisible) {
      _pendingMessage = action.message;
      _pendingAction = action;
      notifyListeners();
    } else {
      _showBrowserNotification(action.message);
    }
  }

  void _showBrowserNotification(String message) {
    final promise = web.Notification.requestPermission();
    promise.toDart.then((perm) {
      if (perm == 'granted'.toJS) {
        web.Notification('工作提醒', web.NotificationOptions(body: message));
      }
    });
  }

  @override
  void dispose() {
    _sedentaryTimer?.cancel();
    _offWorkTimer?.cancel();
    _todoTimer?.cancel();
    web.document.removeEventListener('visibilitychange', _onVisibilityChange.toJS);
    super.dispose();
  }
}
