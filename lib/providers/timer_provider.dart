import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/work_log.dart';

enum TimerStatus { idle, running, paused }

class TimerState {
  final int workLogId;
  final String taskTitle;
  final String taskCategory;
  final TimerStatus status;
  final int elapsedSeconds;

  const TimerState({
    required this.workLogId,
    required this.taskTitle,
    this.taskCategory = '',
    this.status = TimerStatus.running,
    this.elapsedSeconds = 0,
  });

  String get formattedTime {
    final h = (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class TimerProvider extends ChangeNotifier {
  final Map<int, _TimerStateData> _timers = {};

  List<TimerState> get activeTimers =>
      _timers.values.map((d) => d.toState()).toList();

  bool get hasActiveTimers => _timers.isNotEmpty;

  TimerState? getTimer(int workLogId) => _timers[workLogId]?.toState();

  void start(int workLogId, String title, String category,
      {int initialSeconds = 0}) {
    _timers[workLogId] = _TimerStateData(
      workLogId: workLogId,
      taskTitle: title,
      taskCategory: category,
      elapsedSeconds: initialSeconds,
      status: TimerStatus.running,
    );
    _timers[workLogId]!._startTicking(notifyListeners);
    notifyListeners();
  }

  void pause(int workLogId) {
    final data = _timers[workLogId];
    if (data == null) return;
    data.status = TimerStatus.paused;
    data._cancelTimer();
    notifyListeners();
  }

  void resume(int workLogId) {
    final data = _timers[workLogId];
    if (data == null) return;
    data.status = TimerStatus.running;
    data._startTicking(notifyListeners);
    notifyListeners();
  }

  void stop(int workLogId) {
    final data = _timers.remove(workLogId);
    data?._cancelTimer();
    notifyListeners();
  }

  void resumeFromOngoingTask(WorkLog task) {
    if (task.id == null) return;
    final id = task.id!;
    // Don't double-resume if already tracking this task
    if (_timers.containsKey(id)) return;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - task.startTime) ~/ 1000;
    _timers[id] = _TimerStateData(
      workLogId: id,
      taskTitle: task.title,
      taskCategory: task.category,
      elapsedSeconds: elapsed >= 0 ? elapsed : 0,
      status: TimerStatus.running,
    );
    _timers[id]!._startTicking(notifyListeners);
    notifyListeners();
  }

  void stopAll() {
    for (final data in _timers.values) {
      data._cancelTimer();
    }
    _timers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final data in _timers.values) {
      data._cancelTimer();
    }
    _timers.clear();
    super.dispose();
  }
}

class _TimerStateData {
  final int workLogId;
  final String taskTitle;
  final String taskCategory;
  int elapsedSeconds;
  TimerStatus status;
  Timer? _timer;

  _TimerStateData({
    required this.workLogId,
    required this.taskTitle,
    this.taskCategory = '',
    this.elapsedSeconds = 0,
    this.status = TimerStatus.running,
  });

  void _startTicking(VoidCallback notify) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notify();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  TimerState toState() => TimerState(
        workLogId: workLogId,
        taskTitle: taskTitle,
        taskCategory: taskCategory,
        status: status,
        elapsedSeconds: elapsedSeconds,
      );
}
