import 'package:flutter/foundation.dart';
import '../models/work_log.dart';
import '../models/todo_item.dart';
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
  bool _hasServer = false;

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
      final pushResult = await _pushChanges(userId);
      if (!pushResult.ok) {
        _isSyncing = false;
        notifyListeners();
        return pushResult;
      }

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
      // Push unsynced work logs
      final unsyncedLogs = await _db.getUnsyncedLogs(userId);
      final logChanges = unsyncedLogs.map((log) => {
        'clientId': log.id.toString(),
        'title': log.title,
        'category': log.category,
        'startTime': log.startTime,
        'endTime': log.endTime,
        'duration': log.duration,
        'status': log.status,
        'notes': log.notes,
      }).toList();

      // Push unsynced todos
      final unsyncedTodos = await _db.getUnsyncedTodos(userId);
      final todoChanges = unsyncedTodos.map((t) => {
        'clientId': t.id.toString(),
        'title': t.title,
        'description': t.description,
        'priority': t.priority,
        'status': t.status,
        'dueDate': t.dueDate,
        'category': t.category,
        'linkedWorkLogClientId': t.linkedWorkLogId?.toString(),
        'parentClientId': t.parentId?.toString(),
        'recurringRule': t.recurringRule,
        'sortOrder': t.sortOrder,
        'createdAt': t.createdAt,
        'updatedAt': t.updatedAt,
      }).toList();

      if (logChanges.isEmpty && todoChanges.isEmpty) {
        return SyncResult(ok: true, message: 'Nothing to push');
      }

      final result = await _api.sync(logChanges, _lastSyncAt, todoChanges: todoChanges);
      if (!result.ok) {
        return SyncResult(ok: false, message: result.error ?? 'Push failed');
      }

      // Mark pushed logs as synced
      for (final log in unsyncedLogs) {
        if (log.id != null) {
          await _db.markLogSynced(log.id!);
        }
      }

      // Mark pushed todos as synced
      for (final todo in unsyncedTodos) {
        if (todo.id != null) {
          await _db.markTodoSynced(todo.id!);
        }
      }

      final syncAt = result.get<int>('syncAt') ?? DateTime.now().millisecondsSinceEpoch;
      _lastSyncAt = syncAt;

      return SyncResult(ok: true, message: 'Pushed ${logChanges.length} logs + ${todoChanges.length} todos');
    } catch (e) {
      return SyncResult(ok: false, message: 'Push error: $e');
    }
  }

  /// Pull remote changes from the server
  Future<SyncResult> _pullChanges(int userId) async {
    try {
      // Pull work logs
      final logResult = await _api.getWorkLogs(sinceMs: _lastSyncAt);
      if (!logResult.ok) {
        return SyncResult(ok: false, message: logResult.error ?? 'Pull failed');
      }

      final logs = logResult.get<List<dynamic>>('logs') ?? [];
      int logApplied = 0;
      for (final logData in logs) {
        final log = logData as Map<String, dynamic>;
        final clientId = log['clientId']?.toString();
        if (clientId == null) continue;
        final localId = int.tryParse(clientId);
        if (localId == null) continue;

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
        logApplied++;
      }

      // Pull todos
      int todoApplied = 0;
      final todoResult = await _api.getTodos(sinceMs: _lastSyncAt);
      if (todoResult.ok) {
        final todos = todoResult.get<List<dynamic>>('todos') ?? [];
        for (final todoData in todos) {
          final t = todoData as Map<String, dynamic>;
          final clientId = t['clientId']?.toString();
          if (clientId == null) continue;
          final localId = int.tryParse(clientId);
          if (localId == null) continue;

          final todo = TodoItem(
            id: localId,
            userId: userId,
            title: t['title']?.toString() ?? '',
            description: t['description']?.toString() ?? '',
            priority: t['priority'] as int? ?? 1,
            status: t['status'] as int? ?? 0,
            dueDate: t['dueDate'] as int?,
            category: t['category']?.toString() ?? '',
            linkedWorkLogId: t['linkedWorkLogClientId'] != null
                ? int.tryParse(t['linkedWorkLogClientId'].toString())
                : null,
            parentId: t['parentClientId'] != null
                ? int.tryParse(t['parentClientId'].toString())
                : null,
            recurringRule: t['recurringRule']?.toString() ?? '',
            sortOrder: t['sortOrder'] as int? ?? 0,
            createdAt: t['createdAt'] as int? ?? 0,
            updatedAt: t['updatedAt'] as int? ?? 0,
            isSynced: true,
          );
          await _db.updateTodo(todo);
          todoApplied++;
        }
      }

      final syncAt = DateTime.now().millisecondsSinceEpoch;
      _lastSyncAt = syncAt;

      return SyncResult(ok: true,
          message: 'Pulled $logApplied logs + $todoApplied todos');
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
