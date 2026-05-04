import 'package:flutter/foundation.dart';
import '../models/work_log.dart';
import '../services/database_helper.dart';

class WorkLogProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<WorkLog> _todayLogs = [];
  List<WorkLog> _weekLogs = [];
  List<WorkLog> _monthLogs = [];
  WorkLog? _activeLog;

  List<WorkLog> get todayLogs => _todayLogs;
  List<WorkLog> get weekLogs => _weekLogs;
  List<WorkLog> get monthLogs => _monthLogs;
  WorkLog? get activeLog => _activeLog;

  Future<void> loadTodayLogs(int userId) async {
    _todayLogs = await _db.getTodayLogs(userId);
    _activeLog = _todayLogs.where((l) => l.status == 0).firstOrNull ??
        (_todayLogs.isNotEmpty ? _todayLogs.first : null);
    notifyListeners();
  }

  Future<void> loadWeekLogs(int userId) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final weekStart =
        DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
    _weekLogs = await _db.getLogsByDateRange(
      userId,
      weekStart,
      now.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  Future<void> loadMonthLogs(int userId) async {
    final now = DateTime.now();
    final monthStart =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    _monthLogs = await _db.getLogsByDateRange(
      userId,
      monthStart,
      now.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  Future<int> startNewTask(int userId, String title, String category,
      {String notes = ''}) async {
    final log = WorkLog(
      userId: userId,
      title: title,
      category: category,
      startTime: DateTime.now().millisecondsSinceEpoch,
      status: 0,
      notes: notes,
    );
    final id = await _db.insertWorkLog(log);
    _activeLog = log.copyWith(id: id);
    _todayLogs.insert(0, _activeLog!);
    notifyListeners();
    return id;
  }

  Future<void> endTask(int workLogId, int elapsedSeconds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final log = WorkLog(
      id: workLogId,
      userId: _activeLog?.userId ?? 0,
      title: _activeLog?.title ?? '',
      category: _activeLog?.category ?? '',
      startTime: _activeLog?.startTime ?? now,
      endTime: now,
      duration: elapsedSeconds,
      status: 1,
      notes: _activeLog?.notes ?? '',
    );
    await _db.updateWorkLog(log);
    _activeLog = null;
    final idx = _todayLogs.indexWhere((l) => l.id == workLogId);
    if (idx >= 0) _todayLogs[idx] = log;
    notifyListeners();
  }

  Future<void> addManualLog(int userId, String title, String category,
      int startTime, int endTime, String notes) async {
    final log = WorkLog(
      userId: userId,
      title: title,
      category: category,
      startTime: startTime,
      endTime: endTime,
      duration: ((endTime - startTime) ~/ 1000),
      status: 1,
      notes: notes,
    );
    final id = await _db.insertWorkLog(log);
    _todayLogs.insert(0, log.copyWith(id: id));
    _todayLogs.sort((a, b) => b.startTime.compareTo(a.startTime));
    notifyListeners();
  }

  Future<void> deleteLog(int id) async {
    await _db.deleteWorkLog(id);
    _todayLogs.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  Future<void> clearTodayLogs(int userId) async {
    await _db.clearAllData(userId);
    _todayLogs.clear();
    notifyListeners();
  }

  int getTodayTotalSeconds() {
    int total = 0;
    final today = DateTime.now();
    final todayStart =
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    for (final log in _todayLogs) {
      if (log.status == 1 && log.startTime >= todayStart) {
        total += log.duration;
      }
    }
    return total;
  }
}
