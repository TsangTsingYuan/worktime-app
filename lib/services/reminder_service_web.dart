import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/work_log_provider.dart';
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

  String? get pendingMessage => _pendingMessage;
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

  void start(SettingsProvider settings, WorkLogProvider workLogProvider, AuthProvider auth) {
    _settings = settings;
    _workLogProvider = workLogProvider;
    _auth = auth;
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

    DatabaseHelper().getOverdueTodos(userId).then((overdue) {
      for (final todo in overdue) {
        if (todo.id != null && _notifiedTodoIds.add(todo.id!)) {
          _notify('待办「${todo.title}」已过截止时间！');
        }
      }
    });
  }

  // ---- notification dispatch ----

  void _notify(String message) {
    if (_isTabVisible) {
      _pendingMessage = message;
      notifyListeners();
    } else {
      _showBrowserNotification(message);
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
