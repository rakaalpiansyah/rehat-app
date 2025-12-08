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
    _database = await _initDB('rehat_schedule.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Tipe data SQLite
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const boolType = 'INTEGER NOT NULL'; // 0 atau 1
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
        breakDuration $intType
      )
    ''');
  }

  // --- CRUD OPERATIONS ---

  // 1. CREATE (Tambah Jadwal)
  Future<int> create(ScheduleModel schedule) async {
    final db = await instance.database;
    return await db.insert('schedules', schedule.toMap());
  }

  // 2. READ ALL (Ambil Semua Jadwal)
  Future<List<ScheduleModel>> readAllSchedules() async {
    final db = await instance.database;
    final result = await db.query('schedules');

    return result.map((json) => ScheduleModel.fromMap(json)).toList();
  }

  // 3. UPDATE (Edit Jadwal)
  Future<int> update(ScheduleModel schedule) async {
    final db = await instance.database;
    return await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  // 4. DELETE (Hapus Jadwal)
  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Close Database (Opsional)
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}