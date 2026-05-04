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
  static const _dbVersion = 1;

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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        config TEXT NOT NULL DEFAULT ''
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
        FOREIGN KEY (userId) REFERENCES user(id)
      )
    ''');
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
    return db.insert('work_log', log.toMap());
  }

  Future<void> updateWorkLog(WorkLog log) async {
    final db = await database;
    await db.update('work_log', log.toMap(), where: 'id = ?', whereArgs: [log.id]);
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
