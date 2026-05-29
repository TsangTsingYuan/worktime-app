import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/work_log_provider.dart';
import '../providers/todo_provider.dart';
import '../models/reminder_action.dart';

class ReminderService extends ChangeNotifier {
  String? _pendingMessage;

  String? get pendingMessage => _pendingMessage;
  ReminderAction? get pendingAction => null;
  bool get isTabVisible => true;

  void initializeVisibilityListener() {}

  void start(SettingsProvider settings, WorkLogProvider workLogProvider, AuthProvider auth, {TodoProvider? todoProvider}) {}

  void stop() {
    _pendingMessage = null;
    notifyListeners();
  }

  void update(SettingsProvider settings) {}

  void clearPendingMessage() {
    _pendingMessage = null;
    notifyListeners();
  }
}
