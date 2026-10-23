import 'package:drift/drift.dart';

import 'database.dart';
import 'task_importance.dart';
import 'task_repetition.dart';
import 'task_schedule.dart';

/// A task together with its computed streak figures.
class TaskWithStreaks {
  const TaskWithStreaks({
    required this.task,
    required this.schedule,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletions,
    required this.completedToday,
    required this.completedCycles,
    required this.isForToday,
    required this.isCycleDone,
    required this.nextDueDay,
  });

  final StreakTask task;

  /// The calendar of the task, used to know when it comes due.
  final TaskSchedule schedule;

  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;

  /// Whether the task was completed today, whatever its repetition is.
  final bool completedToday;

  /// The cycles in which the task was completed.
  ///
  /// A cycle is the window between two due days, so for a daily task it is
  /// a single day and for a weekly task a whole week.
  final Set<int> completedCycles;

  /// Whether the task belongs to today's section.
  ///
  /// A task belongs to today when it comes due today, or when its current
  /// cycle is still open, which happens when a due day passed without the
  /// task being done. The second case keeps a late task visible instead of
  /// burying it under the tasks of the coming days.
  final bool isForToday;

  /// Whether the cycle the task is in right now is already done.
  final bool isCycleDone;

  /// The next day the task comes due on.
  final DateTime nextDueDay;

  /// Whether the task comes due today.
  bool isDueToday([DateTime? today]) =>
      schedule.isDueOn(today ?? DateTime.now());
}

/// Data access for tasks and their completions.
///
/// Every completion is stored as a row, which is the event log a future
/// streak view will read from. The streak figures shown today are derived
/// from that log through [TaskSchedule], which knows how the days of a task
/// group into cycles.
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
    return _tasksWithCompletions().watch().map(
      (rows) => _group(rows, DateTime.now()),
    );
  }

  /// Loads all active tasks with their streak figures, once.
  Future<List<TaskWithStreaks>> loadTasksWithStreaks() async {
    final rows = await _tasksWithCompletions().get();
    return _group(rows, DateTime.now());
  }

  /// The query behind the task list.
  ///
  /// It joins every active task with its completions, so a single watch
  /// covers both tables. The streak figures are computed in Dart because the
  /// schedule of a task (daily, alternate or weekly) decides how the days
  /// group into cycles.
  Selectable<QueryRow> _tasksWithCompletions() {
    const sql = '''
SELECT
  t.id AS id,
  t.title AS title,
  t.description AS description,
  t.importance AS importance,
  t.repetition AS repetition,
  t.reminder_hour AS reminder_hour,
  t.reminder_minute AS reminder_minute,
  t.created_at AS created_at,
  t.is_archived AS is_archived,
  t.sort_order AS sort_order,
  c.day AS day
FROM streak_tasks t
LEFT JOIN completions c ON c.task_id = t.id
WHERE t.is_archived = 0
ORDER BY t.sort_order ASC, t.id ASC, c.day ASC
''';

    return db.customSelect(sql, readsFrom: {db.streakTasks, db.completions});
  }

  /// Groups the joined rows into tasks and computes their streaks.
  List<TaskWithStreaks> _group(List<QueryRow> rows, DateTime today) {
    final grouped = <int, List<QueryRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.read<int>('id'), () => []).add(row);
    }

    final result = <TaskWithStreaks>[];
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      final task = StreakTask(
        id: first.read<int>('id'),
        title: first.read<String>('title'),
        description: first.read<String>('description'),
        // The converters are not applied to custom queries, so the raw
        // stored integers are mapped by hand here.
        importance: TaskImportance.fromDb(first.read<int>('importance')),
        repetition: TaskRepetition.fromDb(first.read<int>('repetition')),
        reminderHour: first.read<int>('reminder_hour'),
        reminderMinute: first.read<int>('reminder_minute'),
        createdAt: first.read<DateTime>('created_at'),
        isArchived: first.read<bool>('is_archived'),
        sortOrder: first.read<int>('sort_order'),
      );

      final schedule = TaskSchedule(
        anchor: DateTime(
          task.createdAt.year,
          task.createdAt.month,
          task.createdAt.day,
        ),
        repetition: task.repetition,
      );

      final days = <String>[];
      for (final row in entry.value) {
        final day = row.readNullable<String>('day');
        if (day != null) days.add(day);
      }

      final completedCycles = <int>{};
      for (final day in days) {
        final cycle = schedule.cycleOf(parseDay(day));
        if (cycle >= 0) completedCycles.add(cycle);
      }

      final cycle = schedule.cycleOf(today);
      final cycleDone = completedCycles.contains(cycle);
      final dueToday = schedule.isDueOn(today);

      result.add(
        TaskWithStreaks(
          task: task,
          schedule: schedule,
          isForToday: dueToday || !cycleDone,
          isCycleDone: cycleDone,
          nextDueDay: schedule.nextDueDay(today),
          currentStreak: schedule.currentStreak(
            completed: completedCycles,
            today: today,
          ),
          bestStreak: schedule.bestStreak(completed: completedCycles),
          totalCompletions: days.length,
          completedToday: days.contains(dayKey(today)),
          completedCycles: completedCycles,
        ),
      );
    }
    return result;
  }

  /// Creates a task and returns its id.
  ///
  /// [createdAt] anchors the schedule of the task: the repetition counts
  /// from that day, so a task created today with an alternate repetition
  /// comes due today, then in two days, and so on. It only exists so tests
  /// can build a task that already has a history.
  Future<int> createTask({
    required String title,
    required int reminderHour,
    required int reminderMinute,
    String description = '',
    TaskImportance importance = TaskImportance.normal,
    TaskRepetition repetition = TaskRepetition.daily,
    DateTime? createdAt,
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
            repetition: Value(repetition),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            createdAt: createdAt ?? DateTime.now(),
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

  /// Changes how often a task comes due.
  Future<void> updateRepetition(int taskId, TaskRepetition repetition) async {
    await (db.update(db.streakTasks)..where((t) => t.id.equals(taskId))).write(
      StreakTasksCompanion(repetition: Value(repetition)),
    );
  }

  /// Marks a day as completed, or un-completes it if it was already done.
  ///
  /// Every completion is stored, which is the event log a future streak view
  /// will read from.
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
