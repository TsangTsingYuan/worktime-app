import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/work_log.dart';
import '../models/todo_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static Future<Database>? _dbInitFuture;
  static const _dbName = 'worktime.db';
  static const _dbVersion = 4;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbInitFuture ??= _initDatabase();
    _database = await _dbInitFuture;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, _dbName),
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        config TEXT NOT NULL DEFAULT '',
        serverId TEXT,
        token TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE work_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        duration INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        serverId TEXT,
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        isSynced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES user(id)
      )
    ''');
    await _createTodoTable(db);
    await _createPrefsTable(db);
  }

  Future<void> _createPrefsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_prefs (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTodoTable(Database db) async {
    await db.execute('''
      CREATE TABLE todo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        priority INTEGER NOT NULL DEFAULT 1,
        status INTEGER NOT NULL DEFAULT 0,
        dueDate INTEGER,
        category TEXT NOT NULL DEFAULT '',
        linkedWorkLogId INTEGER,
        parentId INTEGER,
        recurringRule TEXT NOT NULL DEFAULT '',
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES user(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE user ADD COLUMN serverId TEXT");
      await db.execute("ALTER TABLE user ADD COLUMN token TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE work_log ADD COLUMN serverId TEXT");
      await db.execute("ALTER TABLE work_log ADD COLUMN createdAt INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE work_log ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE work_log ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0");
    }
    if (oldVersion < 3) {
      await _createTodoTable(db);
    }
    if (oldVersion < 4) {
      await _createPrefsTable(db);
    }
  }

  // ====================== Password Hashing ======================

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ====================== User CRUD ======================

  Future<User?> login(String phone, String password) async {
    final hashed = _hashPassword(password);
    return _loginByHash(phone, hashed);
  }

  /// Login with already-hashed password (for auto-login)
  Future<User?> loginByHash(String phone, String passwordHash) async {
    return _loginByHash(phone, passwordHash);
  }

  Future<User?> _loginByHash(String phone, String hashedPassword) async {
    try {
      final db = await database;
      final maps = await db.query('user',
          where: 'phone = ? AND password = ?', whereArgs: [phone, hashedPassword]);
      if (maps.isEmpty) return null;
      return User.fromMap(maps.first);
    } catch (_) {
      return null;
    }
  }

  Future<User?> register(String phone, String password, String nickname) async {
    final hashed = _hashPassword(password);
    try {
      final db = await database;
      final id = await db.insert('user', {
        'phone': phone,
        'password': hashed,
        'nickname': nickname,
        'config':
            '{"workStart":"09:00","workEnd":"18:00","breakDuration":60,"sedentaryReminder":0,"offWorkReminder":false}',
      });
      return await getUserById(id);
    } catch (_) {
      return null;
    }
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query('user', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update('user', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // ====================== WorkLog CRUD ======================

  Future<int> insertWorkLog(WorkLog log) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = log.copyWith(createdAt: now, updatedAt: now).toMap();
    return db.insert('work_log', data);
  }

  Future<void> updateWorkLog(WorkLog log) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = log.copyWith(updatedAt: now).toMap();
    await db.update('work_log', data, where: 'id = ?', whereArgs: [log.id]);
  }

  Future<void> upsertWorkLog(WorkLog log) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = log.copyWith(updatedAt: now).toMap();
    final existing =
        await db.query('work_log', where: 'id = ?', whereArgs: [log.id]);
    if (existing.isNotEmpty) {
      await db.update('work_log', data, where: 'id = ?', whereArgs: [log.id]);
    } else {
      await db.insert('work_log', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> deleteWorkLog(int id) async {
    final db = await database;
    await db.delete('work_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkLog>> getTodayLogs(int userId) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.query('work_log',
        where: 'userId = ? AND startTime >= ? AND startTime <= ?',
        whereArgs: [userId, start, end],
        orderBy: 'startTime DESC');
    return maps.map((m) => WorkLog.fromMap(m)).toList();
  }

  Future<List<WorkLog>> getLogsByDateRange(
      int userId, int startMs, int endMs) async {
    final db = await database;
    final maps = await db.query('work_log',
        where: 'userId = ? AND startTime >= ? AND startTime <= ?',
        whereArgs: [userId, startMs, endMs],
        orderBy: 'startTime DESC');
    return maps.map((m) => WorkLog.fromMap(m)).toList();
  }

  Future<List<WorkLog>> getUnsyncedLogs(int userId) async {
    final db = await database;
    final maps = await db.query('work_log',
        where: 'userId = ? AND isSynced = 0', whereArgs: [userId]);
    return maps.map((m) => WorkLog.fromMap(m)).toList();
  }

  Future<void> markLogSynced(int logId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('work_log', {'isSynced': 1, 'updatedAt': now},
        where: 'id = ?', whereArgs: [logId]);
  }

  // ====================== Todo CRUD ======================

  Future<int> insertTodo(TodoItem todo) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = todo.copyWith(createdAt: now, updatedAt: now).toMap();
    return db.insert('todo', data);
  }

  Future<void> updateTodo(TodoItem todo) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = todo.copyWith(updatedAt: now).toMap();
    await db.update('todo', data, where: 'id = ?', whereArgs: [todo.id]);
  }

  Future<void> deleteTodo(int id) async {
    final db = await database;
    // Also delete subtasks
    await db.delete('todo', where: 'id = ? OR parentId = ?', whereArgs: [id, id]);
  }

  /// Get all todos for a user, optionally filtered by date range
  Future<List<TodoItem>> getTodos(
    int userId, {
    int? startDay, // epoch ms at start of day
    int? endDay, // epoch ms at end of day
    int? statusFilter,
    int? priorityFilter,
    String? categoryFilter,
    String? searchQuery,
  }) async {
    final db = await database;
    final conditions = <String>['userId = ?'];
    final args = <dynamic>[userId];

    if (statusFilter != null) {
      conditions.add('status = ?');
      args.add(statusFilter);
    }
    if (priorityFilter != null) {
      conditions.add('priority = ?');
      args.add(priorityFilter);
    }
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      conditions.add('category = ?');
      args.add(categoryFilter);
    }
    if (startDay != null && endDay != null) {
      conditions.add('(dueDate IS NULL OR (dueDate >= ? AND dueDate <= ?))');
      args.addAll([startDay, endDay]);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('title LIKE ? OR description LIKE ?');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    final maps = await db.query('todo',
        where: conditions.join(' AND '),
        whereArgs: args,
        orderBy: 'sortOrder ASC, createdAt DESC');
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  /// Get all todos that have a due date in the given date range (for calendar markers)
  Future<List<TodoItem>> getTodosByDateRange(
      int userId, int startMs, int endMs) async {
    final db = await database;
    final maps = await db.query('todo',
        where:
            'userId = ? AND dueDate >= ? AND dueDate <= ? AND parentId IS NULL',
        whereArgs: [userId, startMs, endMs]);
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  /// Get subtasks for a parent todo
  Future<List<TodoItem>> getSubtasks(int parentId) async {
    final db = await database;
    final maps = await db.query('todo',
        where: 'parentId = ?', whereArgs: [parentId], orderBy: 'sortOrder ASC');
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  /// Get completed todos count in a date range (for stats)
  Future<int> getCompletedCount(int userId, int startMs, int endMs) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM todo WHERE userId = ? AND status = 2 AND updatedAt >= ? AND updatedAt <= ?',
      [userId, startMs, endMs],
    );
    return result.first['cnt'] as int;
  }

  /// Get overdue todos
  Future<List<TodoItem>> getOverdueTodos(int userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query('todo',
        where: 'userId = ? AND status != 2 AND dueDate IS NOT NULL AND dueDate < ?',
        whereArgs: [userId, now]);
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<List<TodoItem>> getUnsyncedTodos(int userId) async {
    final db = await database;
    final maps = await db.query('todo',
        where: 'userId = ? AND isSynced = 0 AND parentId IS NULL',
        whereArgs: [userId]);
    return maps.map((m) => TodoItem.fromMap(m)).toList();
  }

  Future<void> markTodoSynced(int todoId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('todo', {'isSynced': 1, 'updatedAt': now},
        where: 'id = ?', whereArgs: [todoId]);
  }

  Future<void> clearAllData(int userId) async {
    final db = await database;
    await db.delete('work_log', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('todo', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('todo');
    await db.delete('work_log');
    await db.delete('user');
  }

  // ====================== App Preferences (key-value) ======================

  Future<void> savePref(String key, String value) async {
    final db = await database;
    await db.insert('app_prefs', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getPref(String key) async {
    final db = await database;
    final maps = await db.query('app_prefs',
        where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> deletePref(String key) async {
    final db = await database;
    await db.delete('app_prefs', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> clearAllPrefs() async {
    final db = await database;
    await db.delete('app_prefs');
  }

  // ====================== Categories ======================

  /// Get all distinct categories from work_log and todo tables
  Future<List<String>> getAllCategories(int userId) async {
    final db = await database;
    final worklogCats = await db.rawQuery(
        'SELECT DISTINCT category FROM work_log WHERE userId = ? AND category != "" ORDER BY category',
        [userId]);
    final todoCats = await db.rawQuery(
        'SELECT DISTINCT category FROM todo WHERE userId = ? AND category != "" ORDER BY category',
        [userId]);
    final set = <String>{};
    for (final row in worklogCats) {
      final c = row['category'] as String?;
      if (c != null && c.isNotEmpty) set.add(c);
    }
    for (final row in todoCats) {
      final c = row['category'] as String?;
      if (c != null && c.isNotEmpty) set.add(c);
    }
    final sorted = set.toList()..sort();
    // Filter out hidden categories
    final hidden = await _getHiddenCategories(userId);
    if (hidden.isNotEmpty) {
      sorted.removeWhere((c) => hidden.contains(c));
    }
    return sorted;
  }

  /// Hidden categories stored in app_prefs as JSON array
  Future<Set<String>> _getHiddenCategories(int userId) async {
    final key = 'hidden_categories_$userId';
    final val = await getPref(key);
    if (val == null || val.isEmpty) return {};
    try {
      final list = (jsonDecode(val) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> hideCategory(int userId, String category) async {
    final key = 'hidden_categories_$userId';
    final current = await _getHiddenCategories(userId);
    current.add(category);
    await savePref(key, jsonEncode(current.toList()));
  }

  Future<void> unhideCategory(int userId, String category) async {
    final key = 'hidden_categories_$userId';
    final current = await _getHiddenCategories(userId);
    current.remove(category);
    await savePref(key, jsonEncode(current.toList()));
  }

  Future<Set<String>> getVisibleCategories(int userId, List<String> allCategories) async {
    final hidden = await _getHiddenCategories(userId);
    return allCategories.where((c) => !hidden.contains(c)).toSet();
  }

  // ─── Credential helpers for "记住密码" / "自动登录" ───

  static const _prefKeyPhone = 'remembered_phone';
  static const _prefKeyPasswordHash = 'remembered_password_hash';
  static const _prefKeyAutoLogin = 'auto_login_enabled';
  static const _prefKeyRememberPwd = 'remember_password_plain';

  Future<void> saveCredentials(String phone, String passwordHash, {bool autoLogin = false}) async {
    await savePref(_prefKeyPhone, phone);
    await savePref(_prefKeyPasswordHash, passwordHash);
    await savePref(_prefKeyAutoLogin, autoLogin ? '1' : '0');
  }

  /// Save the ORIGINAL (plaintext) password for "记住密码" pre-fill on login screen
  Future<void> saveRememberPassword(String password) async {
    await savePref(_prefKeyRememberPwd, password);
  }

  /// Retrieve the saved plaintext password for login screen pre-fill
  Future<String?> getRememberPassword() async {
    return getPref(_prefKeyRememberPwd);
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    final phone = await getPref(_prefKeyPhone);
    final passwordHash = await getPref(_prefKeyPasswordHash);
    final autoLogin = await getPref(_prefKeyAutoLogin);
    if (phone == null || passwordHash == null) return {};
    return {
      'phone': phone,
      'passwordHash': passwordHash,
      'autoLogin': autoLogin,
    };
  }

  Future<bool> isAutoLoginEnabled() async {
    final val = await getPref(_prefKeyAutoLogin);
    return val == '1';
  }

  Future<void> clearCredentials() async {
    await deletePref(_prefKeyPhone);
    await deletePref(_prefKeyPasswordHash);
    await deletePref(_prefKeyAutoLogin);
    await deletePref(_prefKeyRememberPwd);
  }

  /// Get the latest updatedAt timestamp across work_log and todo tables
  Future<int> getLastSyncTimestamp(int userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT MAX(maxTime) as lastSync FROM (
        SELECT MAX(updatedAt) as maxTime FROM work_log WHERE userId = ?
        UNION ALL
        SELECT MAX(updatedAt) as maxTime FROM todo WHERE userId = ?
      )
    ''', [userId, userId]);
    final lastSync = result.first['lastSync'];
    if (lastSync == null) return 0;
    return lastSync as int;
  }
}
