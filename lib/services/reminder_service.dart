import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';
import '../providers/work_log_provider.dart';

class ReminderService extends ChangeNotifier {
  String? _pendingMessage;

  String? get pendingMessage => _pendingMessage;
  bool get isTabVisible => true;

  void initializeVisibilityListener() {}

  void start(SettingsProvider settings, WorkLogProvider workLogProvider) {}

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
