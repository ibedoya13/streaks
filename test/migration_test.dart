import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:streaks/data/database.dart';
import 'package:streaks/data/task_dao.dart';
import 'package:streaks/data/task_importance.dart';
import 'package:streaks/data/task_repetition.dart';

/// Verifies that a database created with an older schema is migrated to the
/// current one without losing data, which is what happens to existing
/// installs.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('streaks_migration');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Builds a database with the v1 schema (no importance column) holding a
  /// task and a completion, exactly as the previous release left it.
  File createV1Database() {
    final file = File('${tempDir.path}/streaks.sqlite');
    final db = sqlite3.open(file.path);

    db.execute('''
      CREATE TABLE streak_tasks (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        reminder_hour INTEGER,
        reminder_minute INTEGER,
        created_at INTEGER NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    db.execute('''
      CREATE TABLE completions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        day TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES streak_tasks (id) ON DELETE CASCADE
      )
    ''');
    db.execute(
      'CREATE UNIQUE INDEX completions_task_id_day '
      'ON completions (task_id, day)',
    );

    final now = DateTime.now();
    db.execute(
      'INSERT INTO streak_tasks (title, description, reminder_hour, '
      'reminder_minute, created_at, is_archived, sort_order) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'Tarea existente',
        'Creada antes de la migración',
        9,
        30,
        now.millisecondsSinceEpoch,
        0,
        1,
      ],
    );
    db.execute(
      'INSERT INTO completions (task_id, day, completed_at) VALUES (?, ?, ?)',
      [1, '2026-10-21', now.millisecondsSinceEpoch],
    );

    // The version the previous release stamped on the database.
    db.execute('PRAGMA user_version = 1');
    db.close();
    return file;
  }

  test('a v1 database is migrated keeping its data', () async {
    final file = createV1Database();

    final db = AppDatabase(NativeDatabase(file), false);
    final dao = TaskDao(db);

    // The task survived the migration.
    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks, hasLength(1));
    expect(tasks.first.task.title, 'Tarea existente');
    expect(tasks.first.task.description, 'Creada antes de la migración');
    expect(tasks.first.task.reminderHour, 9);
    expect(tasks.first.task.reminderMinute, 30);

    // Its completion survived too, so the streak maths still works.
    expect(tasks.first.totalCompletions, 1);

    // And it picked up the default importance.
    expect(tasks.first.task.importance, TaskImportance.normal);

    await db.close();
  });

  test('the migrated database accepts new importance values', () async {
    final file = createV1Database();

    final db = AppDatabase(NativeDatabase(file), false);
    final dao = TaskDao(db);

    final id = (await dao.loadTasksWithStreaks()).first.task.id;
    await dao.updateImportance(id, TaskImportance.critical);

    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.task.importance, TaskImportance.critical);

    await db.close();
  });

  test('the migration stamps the new schema version', () async {
    final file = createV1Database();

    final db = AppDatabase(NativeDatabase(file), false);
    // The connection is opened lazily, so a query is needed to actually run
    // the migration. Reading `schemaVersion` alone does not open the file.
    await TaskDao(db).loadTasksWithStreaks();
    expect(db.schemaVersion, 3);
    await db.close();

    // Verify the version was actually written to the file.
    final check = sqlite3.open(file.path);
    expect(check.select('PRAGMA user_version').first.values.first, 3);
    check.close();
  });

  /// Builds a database with the v2 schema: it has the importance column,
  /// but no repetition, and the reminder can still be null.
  File createV2Database() {
    final file = File('${tempDir.path}/streaks_v2.sqlite');
    final db = sqlite3.open(file.path);

    db.execute('''
      CREATE TABLE streak_tasks (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        importance INTEGER NOT NULL DEFAULT 0,
        reminder_hour INTEGER,
        reminder_minute INTEGER,
        created_at INTEGER NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    db.execute('''
      CREATE TABLE completions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        day TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES streak_tasks (id) ON DELETE CASCADE
      )
    ''');
    db.execute(
      'CREATE UNIQUE INDEX completions_task_id_day '
      'ON completions (task_id, day)',
    );

    final now = DateTime.now();
    // A task with a reminder.
    db.execute(
      'INSERT INTO streak_tasks (title, description, importance, '
      'reminder_hour, reminder_minute, created_at, is_archived, sort_order) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      ['Con aviso', '', 1, 18, 30, now.millisecondsSinceEpoch, 0, 1],
    );
    // And one without, which is what the migration has to fix.
    db.execute(
      'INSERT INTO streak_tasks (title, description, importance, '
      'reminder_hour, reminder_minute, created_at, is_archived, sort_order) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      ['Sin aviso', '', 0, null, null, now.millisecondsSinceEpoch, 0, 2],
    );

    db.execute('PRAGMA user_version = 2');
    db.close();
    return file;
  }

  test('a v2 database gets a repetition and a mandatory reminder', () async {
    final file = createV2Database();

    final db = AppDatabase(NativeDatabase(file), false);
    final dao = TaskDao(db);
    final tasks = await dao.loadTasksWithStreaks();

    expect(tasks, hasLength(2));

    // The task that had a reminder kept it.
    final withReminder = tasks.firstWhere((t) => t.task.title == 'Con aviso');
    expect(withReminder.task.reminderHour, 18);
    expect(withReminder.task.reminderMinute, 30);
    expect(withReminder.task.importance, TaskImportance.critical);

    // The one without got a default instead of a null.
    final withoutReminder = tasks.firstWhere(
      (t) => t.task.title == 'Sin aviso',
    );
    expect(withoutReminder.task.reminderHour, 9);
    expect(withoutReminder.task.reminderMinute, 0);

    // Everything became daily, the repetition of the old releases.
    expect(
      tasks.every((t) => t.task.repetition == TaskRepetition.daily),
      isTrue,
    );

    await db.close();
  });

  test('the reminder column is not nullable after the migration', () async {
    final file = createV2Database();

    final db = AppDatabase(NativeDatabase(file), false);
    await TaskDao(db).loadTasksWithStreaks();
    await db.close();

    final check = sqlite3.open(file.path);
    final columns = check.select('PRAGMA table_info(streak_tasks)');
    final reminder = columns.firstWhere((c) => c['name'] == 'reminder_hour');
    expect(reminder['notnull'], 1);
    check.close();
  });

  test('the migrated database can still be reopened', () async {
    final file = createV1Database();

    final first = AppDatabase(NativeDatabase(file), false);
    await TaskDao(first).loadTasksWithStreaks();
    await first.close();

    // Reopening must not try to migrate again.
    final second = AppDatabase(NativeDatabase(file), false);
    final tasks = await TaskDao(second).loadTasksWithStreaks();
    expect(tasks, hasLength(1));
    await second.close();
  });
}
