
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'counter_data.dart';

class CounterDatabase {
  CounterDatabase._();

  static final CounterDatabase instance = CounterDatabase._();

  Database? _database;
  String? _backupPath;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();

    _database = await openDatabase(
      join(dbPath, 'counter_app.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE counters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            count INTEGER NOT NULL,
            background INTEGER NOT NULL,
            appBar INTEGER NOT NULL,
            accent INTEGER NOT NULL,
            text INTEGER NOT NULL,
            countColor INTEGER NOT NULL,
            inputBackground INTEGER NOT NULL,
            border INTEGER NOT NULL,
            reset INTEGER NOT NULL,
            buttonText INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<String> get backupPath async {
    if (_backupPath != null) return _backupPath!;

    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(join(directory.path, 'counter_backups'));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    _backupPath = join(folder.path, 'counters_backup.json');
    return _backupPath!;
  }

  Future<List<CounterData>> loadCounters() async {
    final db = await database;

    final rows = await db.query(
      'counters',
      orderBy: 'id ASC',
    );

    if (rows.isNotEmpty) {
      return rows.map((row) => CounterData.fromMap(row)).toList();
    }

    // If database is empty, try recovering the local backup.
    final restored = await _restoreBackup();

    if (restored.isNotEmpty) {
      return restored;
    }

    return [];
  }

  Future<int?> loadSelectedId() async {
    final db = await database;

    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['selected_counter_id'],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return int.tryParse(rows.first['value'] as String);
  }

  Future<void> saveSelectedId(int id) async {
    final db = await database;

    await db.insert(
      'settings',
      {
        'key': 'selected_counter_id',
        'value': id.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await createBackup();
  }

  Future<int> saveCounter(CounterData counter) async {
    final db = await database;

    final id = await db.insert(
      'counters',
      counter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    counter.id ??= id;

    await createBackup();

    return counter.id!;
  }

  Future<void> deleteCounter(int id) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'counters',
        where: 'id = ?',
        whereArgs: [id],
      );

      final selected = await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['selected_counter_id'],
      );

      if (selected.isNotEmpty &&
          selected.first['value'] == id.toString()) {
        await txn.delete(
          'settings',
          where: 'key = ?',
          whereArgs: ['selected_counter_id'],
        );
      }
    });

    await createBackup();
  }

  Future<void> createBackup() async {
    final db = await database;

    final counters = await db.query(
      'counters',
      orderBy: 'id ASC',
    );

    final settings = await db.query('settings');

    final backup = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'counters': counters,
      'settings': settings,
    };

    final path = await backupPath;
    final file = File(path);
    final tempFile = File('$path.tmp');

    await tempFile.writeAsString(
      jsonEncode(backup),
      flush: true,
    );

    if (await file.exists()) {
      await file.delete();
    }

    await tempFile.rename(path);
  }

  Future<List<CounterData>> _restoreBackup() async {
    try {
      final path = await backupPath;
      final file = File(path);

      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final backup = jsonDecode(content);

      if (backup['version'] != 1) return [];

      final db = await database;

      final rows = backup['counters'] as List;

      await db.transaction((txn) async {
        for (final row in rows) {
          final counter = Map<String, dynamic>.from(row);

          await txn.insert(
            'counters',
            counter,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        final settings = backup['settings'] as List;

        for (final row in settings) {
          await txn.insert(
            'settings',
            Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return rows
          .map((row) => CounterData.fromMap(
                Map<String, dynamic>.from(row),
              ))
          .toList();
    } catch (e) {
      debugPrint('Backup recovery failed: $e');
      return [];
    }
  }
}
