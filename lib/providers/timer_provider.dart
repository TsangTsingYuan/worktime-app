import 'dart:async';
import 'package:flutter/foundation.dart';

enum TimerStatus { idle, running, paused }

class TimerProvider extends ChangeNotifier {
  TimerStatus _status = TimerStatus.idle;
  int _elapsedSeconds = 0;
  int? _workLogId;
  String _taskTitle = '';
  String _taskCategory = '';
  Timer? _timer;

  TimerStatus get status => _status;
  int get elapsedSeconds => _elapsedSeconds;
  int? get workLogId => _workLogId;
  String get taskTitle => _taskTitle;
  String get taskCategory => _taskCategory;

  String get formattedTime {
    final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void start(int workLogId, String title, String category, {int initialSeconds = 0}) {
    _status = TimerStatus.running;
    _workLogId = workLogId;
    _taskTitle = title;
    _taskCategory = category;
    _elapsedSeconds = initialSeconds;
    _startTicking();
    notifyListeners();
  }

  void pause() {
    _status = TimerStatus.paused;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    _status = TimerStatus.running;
    _startTicking();
    notifyListeners();
  }

  void stop() {
    _status = TimerStatus.idle;
    _timer?.cancel();
    _elapsedSeconds = 0;
    _workLogId = null;
    _taskTitle = '';
    _taskCategory = '';
    notifyListeners();
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
