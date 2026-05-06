import 'package:flutter/foundation.dart';
import '../models/work_log.dart';
import '../services/api_client.dart';
import '../services/database_helper.dart';

/// Offline-first sync service.
/// Local SQLite is the primary data source.
/// Remote server is updated in the background when network is available.
class SyncService extends ChangeNotifier {
  final ApiClient _api;
  final DatabaseHelper _db;
  bool _isSyncing = false;
  int _lastSyncAt = 0;
  bool _hasServer = false; // true if we've ever connected to the server

  SyncService(this._api, this._db);

  bool get isSyncing => _isSyncing;
  bool get hasServer => _hasServer;
  int get lastSyncAt => _lastSyncAt;

  /// Mark server as available (after successful login/register via API)
  void markServerAvailable() {
    _hasServer = true;
  }

  /// Full sync: push local changes then pull remote changes
  Future<SyncResult> sync(int userId) async {
    if (_isSyncing) return SyncResult(ok: true, message: 'Already syncing');
    if (!_hasServer) return SyncResult(ok: false, message: 'No server configured');

    _isSyncing = true;
    notifyListeners();

    try {
      // 1. Push local unsynced changes
      final pushResult = await _pushChanges(userId);
      if (!pushResult.ok) {
        _isSyncing = false;
        notifyListeners();
        return pushResult;
      }

      // 2. Pull remote changes
      final pullResult = await _pullChanges(userId);
      _isSyncing = false;
      notifyListeners();
      return pullResult;
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      return SyncResult(ok: false, message: 'Sync error: $e');
    }
  }

  /// Push local changes to the server
  Future<SyncResult> _pushChanges(int userId) async {
    try {
      // Get all unsynced logs for the user
      final unsyncedLogs = await _db.getUnsyncedLogs(userId);
      if (unsyncedLogs.isEmpty) {
        return SyncResult(ok: true, message: 'Nothing to push');
      }

      final changes = unsyncedLogs.map((log) => {
        'clientId': log.id.toString(),
        'title': log.title,
        'category': log.category,
        'startTime': log.startTime,
        'endTime': log.endTime,
        'duration': log.duration,
        'status': log.status,
        'notes': log.notes,
        'startTimeMs': log.startTime,
      }).toList();

      final result = await _api.sync(changes, _lastSyncAt);
      if (!result.ok) {
        return SyncResult(ok: false, message: result.error ?? 'Push failed');
      }

      // Mark pushed logs as synced
      for (final log in unsyncedLogs) {
        if (log.id != null) {
          await _db.markLogSynced(log.id!);
        }
      }

      // Update sync timestamp
      final syncAt = result.get<int>('syncAt') ?? DateTime.now().millisecondsSinceEpoch;
      _lastSyncAt = syncAt;

      return SyncResult(ok: true, message: 'Pushed ${unsyncedLogs.length} changes');
    } catch (e) {
      return SyncResult(ok: false, message: 'Push error: $e');
    }
  }

  /// Pull remote changes from the server
  Future<SyncResult> _pullChanges(int userId) async {
    try {
      final result = await _api.getWorkLogs(sinceMs: _lastSyncAt);
      if (!result.ok) {
        return SyncResult(ok: false, message: result.error ?? 'Pull failed');
      }

      final logs = result.get<List<dynamic>>('logs') ?? [];
      if (logs.isEmpty) {
        return SyncResult(ok: true, message: 'No new data');
      }

      int applied = 0;
      for (final logData in logs) {
        final log = logData as Map<String, dynamic>;
        final clientId = log['clientId']?.toString();
        if (clientId == null) continue;

        final localId = int.tryParse(clientId);
        if (localId == null) continue;

        // Convert server data to local WorkLog and upsert
        final workLog = WorkLog(
          id: localId,
          userId: userId,
          title: log['title']?.toString() ?? '',
          category: log['category']?.toString() ?? '',
          startTime: log['startTime'] as int? ?? 0,
          endTime: log['endTime'] as int?,
          duration: log['duration'] as int? ?? 0,
          status: log['status'] as int? ?? 0,
          notes: log['notes']?.toString() ?? '',
        );

        await _db.upsertWorkLog(workLog);
        applied++;
      }

      final syncAt = DateTime.now().millisecondsSinceEpoch;
      _lastSyncAt = syncAt;

      return SyncResult(ok: true, message: 'Pulled $applied changes');
    } catch (e) {
      return SyncResult(ok: false, message: 'Pull error: $e');
    }
  }
}

class SyncResult {
  final bool ok;
  final String message;

  SyncResult({required this.ok, required this.message});
}
