import 'package:drift/drift.dart';

import 'connection.dart';
import 'task_importance.dart';
import 'task_repetition.dart';

part 'database.g.dart';

/// A recurring habit the user is building a streak on.
class StreakTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  TextColumn get description => text().withDefault(const Constant(''))();

  /// How insistent this task's reminders should be.
  ///
  /// Stored as an integer through a converter, so the levels can be added or
  /// reordered later without invalidating the data already stored.
  ///
  /// The default is written in the raw stored form, because that is what
  /// SQLite puts in the `CREATE TABLE` statement and what the migration
  /// needs when adding the column to a table that already has rows.
  IntColumn get importance => integer()
      .map(const TaskImportanceConverter())
      .withDefault(const Constant(TaskImportance.normalDbValue))();

  /// How often the task comes due.
  IntColumn get repetition => integer()
      .map(const TaskRepetitionConverter())
      .withDefault(const Constant(TaskRepetition.dailyDbValue))();

  /// Local time of the daily reminder. Every task has one.
  IntColumn get reminderHour => integer()();

  /// Local time of the daily reminder. Every task has one.
  IntColumn get reminderMinute => integer()();

  /// When the task was created, used as the lower bound for streak maths.
  DateTimeColumn get createdAt => dateTime()();

  /// Soft delete, so historical completions are never silently lost.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// User-controlled ordering on the home screen.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// One completed day for a task. The pair (task, day) is unique, which makes
/// "toggle" a plain insert-or-delete.
class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get taskId =>
      integer().references(StreakTasks, #id, onDelete: KeyAction.cascade)();

  /// Midnight of the day this completion belongs to, stored as an ISO date
  /// string (yyyy-MM-dd) so days are comparable and timezone-stable.
  TextColumn get day => text()();

  DateTimeColumn get completedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {taskId, day},
  ];
}

@DriftDatabase(tables: [StreakTasks, Completions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor, bool seedExampleData = true])
    : _seedExampleData = seedExampleData,
      super(executor ?? openConnection());

  /// Whether a freshly created database is populated with example routines.
  /// Tests turn this off so they start from an empty database.
  final bool _seedExampleData;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      if (_seedExampleData) await _seedExamples();
    },
    onUpgrade: (m, from, to) async {
      // v1 -> v2: tasks gained an importance level. Existing tasks become
      // `normal`, which is what the column default already says.
      if (from < 2) {
        await m.addColumn(streakTasks, streakTasks.importance);
      }
      // v2 -> v3: tasks gained a repetition and the reminder became
      // mandatory.
      if (from < 3) {
        await m.addColumn(streakTasks, streakTasks.repetition);

        // The reminder time used to be optional. Give the tasks that have
        // none a default before the columns become NOT NULL, because
        // SQLite cannot copy a NULL into a NOT NULL column.
        await customStatement(
          'UPDATE streak_tasks SET reminder_hour = 9 WHERE reminder_hour IS NULL',
        );
        await customStatement(
          'UPDATE streak_tasks SET reminder_minute = 0 WHERE reminder_minute IS NULL',
        );

        // Rebuilding the table is the only way to make a column NOT NULL.
        await m.alterTable(TableMigration(streakTasks));
      }
    },
    beforeOpen: (details) async {
      // Required for the ON DELETE CASCADE on completions to actually fire.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Populates a first run with a couple of example routines so the app is
  /// not an empty screen on first launch. Only ever runs when the database
  /// is created, never on later opens.
  Future<void> _seedExamples() async {
    final now = DateTime.now();
    DateTime dayOffset(int days) =>
        DateTime(now.year, now.month, now.day - days);

    final water = await into(streakTasks).insert(
      StreakTasksCompanion.insert(
        title: 'Tomar 2 litros de agua',
        description: const Value('Rutina diaria de hidratación'),
        reminderHour: 9,
        reminderMinute: 0,
        createdAt: now,
        sortOrder: const Value(1),
      ),
    );

    final walk = await into(streakTasks).insert(
      StreakTasksCompanion.insert(
        title: 'Caminar 30 minutos',
        description: const Value('Salir a caminar o correr'),
        reminderHour: 18,
        reminderMinute: 30,
        createdAt: now,
        sortOrder: const Value(2),
      ),
    );

    await batch((batch) {
      batch.insertAll(completions, [
        for (final days in [3, 2, 1])
          CompletionsCompanion.insert(
            taskId: water,
            day: _dayKey(dayOffset(days)),
            completedAt: now,
          ),
        CompletionsCompanion.insert(
          taskId: walk,
          day: _dayKey(dayOffset(1)),
          completedAt: now,
        ),
      ]);
    });
  }

  static String _dayKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
