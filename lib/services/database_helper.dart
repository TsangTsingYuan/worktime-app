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
  static const _dbName = 'worktime.db';
  static const _dbVersion = 3;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
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
  }

  // ====================== User CRUD ======================

  Future<User?> login(String phone, String password) async {
    try {
      final db = await database;
      final maps = await db.query('user',
          where: 'phone = ? AND password = ?', whereArgs: [phone, password]);
      if (maps.isEmpty) return null;
      return User.fromMap(maps.first);
    } catch (_) {
      return null;
    }
  }

  Future<User?> register(String phone, String password, String nickname) async {
    try {
      final db = await database;
      final id = await db.insert('user', {
        'phone': phone,
        'password': password,
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
      conditions.add('dueDate >= ? AND dueDate <= ?');
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
}
