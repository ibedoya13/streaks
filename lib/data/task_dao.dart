import 'package:drift/drift.dart';

import 'database.dart';
import 'task_importance.dart';

/// A task together with its computed streak figures.
class TaskWithStreaks {
  const TaskWithStreaks({
    required this.task,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletions,
    required this.completedToday,
  });

  final StreakTask task;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final bool completedToday;
}

/// Data access for tasks and their completions.
///
/// The streak maths runs in SQL rather than in Dart. "How many consecutive
/// days end today?" is a gap-and-islands problem: SQLite answers it with a
/// window function in a single pass over the completions table, so the Dart
/// side never has to load the history into memory.
class TaskDao {
  TaskDao(this.db);

  final AppDatabase db;

  /// ISO date (yyyy-MM-dd) for the local calendar day of [date].
  static String dayKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Parses an ISO date key back into a local DateTime at midnight.
  static DateTime parseDay(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Watches all active tasks with their streak figures.
  ///
  /// Drift re-runs this query automatically whenever `streak_tasks` or
  /// `completions` change, so the UI stays in sync without manual refreshes.
  Stream<List<TaskWithStreaks>> watchTasksWithStreaks() {
    final today = dayKey(DateTime.now());
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));

    return _streakSelect(
      today,
      yesterday,
    ).watch().map((rows) => rows.map(_mapRow).toList(growable: false));
  }

  /// Loads all active tasks with their streak figures, once.
  Future<List<TaskWithStreaks>> loadTasksWithStreaks() async {
    final today = dayKey(DateTime.now());
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final rows = await _streakSelect(today, yesterday).get();
    return rows.map(_mapRow).toList(growable: false);
  }

  /// The streak query.
  ///
  /// The `islands` CTE groups consecutive completion days into runs: the day
  /// number minus the row number is constant within a run and differs between
  /// runs, so grouping by it yields the runs directly.
  ///
  /// The current streak is the run that ends today, or that ended yesterday
  /// (the streak stays alive until the end of today). The best streak is the
  /// longest run ever.
  Selectable<QueryRow> _streakSelect(String today, String yesterday) {
    const sql = '''
WITH days AS (
  SELECT task_id, CAST(julianday(day) AS INTEGER) AS d
  FROM completions
),
islands AS (
  SELECT
    task_id,
    d,
    d - ROW_NUMBER() OVER (PARTITION BY task_id ORDER BY d) AS grp
  FROM days
),
runs AS (
  SELECT task_id, grp, COUNT(*) AS len, MAX(d) AS last_day
  FROM islands
  GROUP BY task_id, grp
)
SELECT
  t.id AS id,
  t.title AS title,
  t.description AS description,
  t.importance AS importance,
  t.reminder_hour AS reminder_hour,
  t.reminder_minute AS reminder_minute,
  t.created_at AS created_at,
  t.is_archived AS is_archived,
  t.sort_order AS sort_order,
  COALESCE(
    (SELECT r.len FROM runs r
      WHERE r.task_id = t.id
        AND r.last_day IN (CAST(julianday(?1) AS INTEGER),
                           CAST(julianday(?2) AS INTEGER))
      ORDER BY r.last_day DESC
      LIMIT 1),
    0
  ) AS current_streak,
  COALESCE((SELECT MAX(r.len) FROM runs r WHERE r.task_id = t.id), 0)
    AS best_streak,
  (SELECT COUNT(*) FROM completions c WHERE c.task_id = t.id)
    AS total_completions,
  EXISTS(
    SELECT 1 FROM completions c
    WHERE c.task_id = t.id AND c.day = ?1
  ) AS completed_today
FROM streak_tasks t
WHERE t.is_archived = 0
ORDER BY t.sort_order ASC, t.id ASC
''';

    return db.customSelect(
      sql,
      variables: [Variable.withString(today), Variable.withString(yesterday)],
      readsFrom: {db.streakTasks, db.completions},
    );
  }

  TaskWithStreaks _mapRow(QueryRow row) {
    return TaskWithStreaks(
      task: StreakTask(
        id: row.read<int>('id'),
        title: row.read<String>('title'),
        description: row.read<String>('description'),
        // The converter is not applied to custom queries, so the raw stored
        // integer is mapped by hand here.
        importance: TaskImportance.fromDb(row.read<int>('importance')),
        reminderHour: row.readNullable<int>('reminder_hour'),
        reminderMinute: row.readNullable<int>('reminder_minute'),
        createdAt: row.read<DateTime>('created_at'),
        isArchived: row.read<bool>('is_archived'),
        sortOrder: row.read<int>('sort_order'),
      ),
      currentStreak: row.read<int>('current_streak'),
      bestStreak: row.read<int>('best_streak'),
      totalCompletions: row.read<int>('total_completions'),
      completedToday: row.read<bool>('completed_today'),
    );
  }

  /// Creates a task and returns its id.
  Future<int> createTask({
    required String title,
    String description = '',
    TaskImportance importance = TaskImportance.normal,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final last =
        await (db.select(db.streakTasks)
              ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    final nextOrder = (last?.sortOrder ?? 0) + 1;
    return db
        .into(db.streakTasks)
        .insert(
          StreakTasksCompanion.insert(
            title: title,
            description: Value(description),
            importance: Value(importance),
            reminderHour: Value(reminderHour),
            reminderMinute: Value(reminderMinute),
            createdAt: DateTime.now(),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  /// Changes the importance level of a task.
  Future<void> updateImportance(int taskId, TaskImportance importance) async {
    await (db.update(db.streakTasks)..where((t) => t.id.equals(taskId))).write(
      StreakTasksCompanion(importance: Value(importance)),
    );
  }

  /// Marks a day as completed, or un-completes it if it was already done.
  Future<void> toggleCompletion(int taskId, DateTime day) async {
    final key = dayKey(day);
    final existing =
        await (db.select(db.completions)
              ..where((c) => c.taskId.equals(taskId) & c.day.equals(key)))
            .getSingleOrNull();

    if (existing != null) {
      await (db.delete(
        db.completions,
      )..where((c) => c.id.equals(existing.id))).go();
    } else {
      await db
          .into(db.completions)
          .insert(
            CompletionsCompanion.insert(
              taskId: taskId,
              day: key,
              completedAt: DateTime.now(),
            ),
          );
    }
  }

  /// Soft-deletes a task, keeping its completions for history.
  Future<void> archiveTask(int taskId) async {
    await (db.update(db.streakTasks)..where((t) => t.id.equals(taskId))).write(
      const StreakTasksCompanion(isArchived: Value(true)),
    );
  }

  /// Permanently removes a task and all of its completions.
  Future<void> deleteTask(int taskId) async {
    await (db.delete(db.streakTasks)..where((t) => t.id.equals(taskId))).go();
  }
}
