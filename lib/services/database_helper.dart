// File: lib/services/database_helper.dart
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/schedule_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rehat_schedule_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const boolType = 'INTEGER NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE schedules (
        id $idType,
        title $textType,
        startTime $textType,
        endTime $textType,
        activeDays $textType,
        isActive $boolType,
        totalDuration $intType,
        intervalDuration $intType,
        breakDuration $intType,
        delayMinutes $intType DEFAULT 0  -- ✅ KOLOM BARU
      )
    ''');
  }

  // --- CRUD OPERATIONS ---

  // 1. CREATE
  Future<int> create(ScheduleModel schedule) async {
    final db = await instance.database;
    return await db.insert('schedules', schedule.toMap());
  }

  // 2. READ ALL
  Future<List<ScheduleModel>> readAllSchedules() async {
    final db = await instance.database;
    final result = await db.query('schedules');
    return result.map((json) => ScheduleModel.fromMap(json)).toList();
  }

  // ✅ 3. READ ONE (BARU: Untuk update saat Snooze)
  Future<ScheduleModel?> readSchedule(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ScheduleModel.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // 4. UPDATE
  Future<int> update(ScheduleModel schedule) async {
    final db = await instance.database;
    return await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  // 5. DELETE
  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}