import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/work_log.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const _dbName = 'worktime.db';
  static const _dbVersion = 2;

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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration v1 → v2: add sync fields
      await db.execute("ALTER TABLE user ADD COLUMN serverId TEXT");
      await db.execute("ALTER TABLE user ADD COLUMN token TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE work_log ADD COLUMN serverId TEXT");
      await db.execute("ALTER TABLE work_log ADD COLUMN createdAt INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE work_log ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE work_log ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0");
    }
  }

  // ---- User CRUD ----

  Future<User?> login(String phone, String password) async {
    try {
      final db = await database;
      final maps = await db.query(
        'user',
        where: 'phone = ? AND password = ?',
        whereArgs: [phone, password],
      );
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
        'config': '{"workStart":"09:00","workEnd":"18:00","breakDuration":60,"sedentaryReminder":0,"offWorkReminder":false}',
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

  // ---- WorkLog CRUD ----

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

  /// Upsert by local ID (used when pulling remote changes)
  Future<void> upsertWorkLog(WorkLog log) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = log.copyWith(updatedAt: now).toMap();
    final existing = await db.query('work_log', where: 'id = ?', whereArgs: [log.id]);
    if (existing.isNotEmpty) {
      await db.update('work_log', data, where: 'id = ?', whereArgs: [log.id]);
    } else {
      // Use provided id as-is for upsert
      await db.insert('work_log', data,
          conflictAlgorithm: ConflictAlgorithm.replace);
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
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.query(
      'work_log',
      where: 'userId = ? AND startTime >= ? AND startTime <= ?',
      whereArgs: [userId, start, end],
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => WorkLog.fromMap(m)).toList();
  }

  Future<List<WorkLog>> getLogsByDateRange(int userId, int startMs, int endMs) async {
    final db = await database;
    final maps = await db.query(
      'work_log',
      where: 'userId = ? AND startTime >= ? AND startTime <= ?',
      whereArgs: [userId, startMs, endMs],
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => WorkLog.fromMap(m)).toList();
  }

  /// Get all unsynced work logs for a user
  Future<List<WorkLog>> getUnsyncedLogs(int userId) async {
    final db = await database;
    final maps = await db.query(
      'work_log',
      where: 'userId = ? AND isSynced = 0',
      whereArgs: [userId],
    );
    return maps.map((m) => WorkLog.fromMap(m)).toList();
  }

  /// Mark a single work log as synced
  Future<void> markLogSynced(int logId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'work_log',
      {'isSynced': 1, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Future<void> clearAllData(int userId) async {
    final db = await database;
    await db.delete('work_log', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('work_log');
    await db.delete('user');
  }
}
