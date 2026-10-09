import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';

import 'hindrance_storage_platform.dart';

/// Durable, account-scoped storage for task snapshots and local hindrance work.
class HindranceLocalStore {
  HindranceLocalStore._();

  static final HindranceLocalStore instance = HindranceLocalStore._();
  static Database? _database;
  static Future<Database>? _databaseOpening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_databaseOpening != null) return _databaseOpening!;
    final opening = _openDatabase();
    _databaseOpening = opening;
    try {
      return await opening;
    } catch (_) {
      _databaseOpening = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final dbPath = await prepareHindranceDatabasePath();
    final database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_snapshots (
            owner_id TEXT NOT NULL,
            task_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            cached_at TEXT NOT NULL,
            PRIMARY KEY (owner_id, task_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE hindrance_reports (
            report_id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            state TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE hindrance_media (
            media_id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            report_id TEXT NOT NULL,
            filename TEXT NOT NULL,
            bytes BLOB NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE hindrance_media (
              media_id TEXT PRIMARY KEY,
              owner_id TEXT NOT NULL,
              report_id TEXT NOT NULL,
              filename TEXT NOT NULL,
              bytes BLOB NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
    _database = database;
    return database;
  }

  Future<void> saveTasks(
    String ownerId,
    List<Map<String, dynamic>> tasks,
  ) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'task_snapshots',
        where: 'owner_id = ?',
        whereArgs: [ownerId],
      );
      final batch = txn.batch();
      for (final task in tasks) {
        final taskId = (task['id'] ?? task['taskId'] ?? task['task_id'] ?? '')
            .toString();
        if (taskId.isEmpty) continue;
        batch.insert('task_snapshots', {
          'owner_id': ownerId,
          'task_id': taskId,
          'payload': jsonEncode(task),
          'cached_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> loadTasks(String ownerId) async {
    final db = await database;
    final rows = await db.query(
      'task_snapshots',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'cached_at DESC',
    );
    return rows
        .map((row) => jsonDecode(row['payload']! as String))
        .whereType<Map>()
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
  }

  Future<void> saveReport({
    required String reportId,
    required String ownerId,
    required String state,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
  }) async {
    final db = await database;
    await db.insert('hindrance_reports', {
      'report_id': reportId,
      'owner_id': ownerId,
      'state': state,
      'payload': jsonEncode(payload),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> loadReports(String ownerId) async {
    final db = await database;
    final rows = await db.query(
      'hindrance_reports',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) {
      final payload =
          jsonDecode(row['payload']! as String) as Map<String, dynamic>;
      return {
        ...payload,
        'reportId': row['report_id'],
        'queueState': row['state'],
        'createdAt': row['created_at'],
      };
    }).toList();
  }

  Future<void> saveMediaBytes({
    required String mediaId,
    required String ownerId,
    required String reportId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final db = await database;
    await db.insert('hindrance_media', {
      'media_id': mediaId,
      'owner_id': ownerId,
      'report_id': reportId,
      'filename': filename,
      'bytes': bytes,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Uint8List?> loadMediaBytes(String mediaId) async {
    final db = await database;
    final rows = await db.query(
      'hindrance_media',
      columns: ['bytes'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.first['bytes']! as List<int>);
  }

  Future<void> deleteMediaBytes(String mediaId) async {
    final db = await database;
    await db.delete(
      'hindrance_media',
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
  }
}
