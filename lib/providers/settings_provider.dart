import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/database_helper.dart';

class WorkSettings {
  String workStart;
  String workEnd;
  int breakDuration;
  int sedentaryReminder; // minutes, 0 = disabled
  bool offWorkReminder;

  WorkSettings({
    this.workStart = '09:00',
    this.workEnd = '18:00',
    this.breakDuration = 60,
    this.sedentaryReminder = 0,
    this.offWorkReminder = false,
  });

  Map<String, dynamic> toJson() => {
        'workStart': workStart,
        'workEnd': workEnd,
        'breakDuration': breakDuration,
        'sedentaryReminder': sedentaryReminder,
        'offWorkReminder': offWorkReminder,
      };

  static int _parseSedentaryReminder(dynamic value) {
    if (value is int) return value;
    if (value is bool) return value ? 60 : 0; // migrate old format
    return 0;
  }

  factory WorkSettings.fromJson(Map<String, dynamic> json) => WorkSettings(
        workStart: json['workStart'] ?? '09:00',
        workEnd: json['workEnd'] ?? '18:00',
        breakDuration: json['breakDuration'] ?? 60,
        sedentaryReminder: _parseSedentaryReminder(json['sedentaryReminder']),
        offWorkReminder: json['offWorkReminder'] ?? false,
      );
}

class SettingsProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  WorkSettings _settings = WorkSettings();

  WorkSettings get settings => _settings;

  void loadFromJson(String configJson) {
    if (configJson.isNotEmpty) {
      try {
        _settings = WorkSettings.fromJson(jsonDecode(configJson));
      } catch (_) {
        _settings = WorkSettings();
      }
    }
    notifyListeners();
  }

  Future<void> updateSettings(WorkSettings newSettings, int userId) async {
    _settings = newSettings;
    final json = jsonEncode(newSettings.toJson());
    final user = await _db.getUserById(userId);
    if (user != null) {
      await _db.updateUser(user.copyWith(config: json));
    }
    notifyListeners();
  }

  int get breakDurationSeconds => _settings.breakDuration * 60;
}
