import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/database.dart';
import 'package:streaks/data/task_dao.dart';
import 'package:streaks/data/task_importance.dart';
import 'package:streaks/data/task_repetition.dart';

void main() {
  late AppDatabase db;
  late TaskDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(), false);
    dao = TaskDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - n);
  }

  /// Creates a task, giving it the mandatory reminder when none is passed.
  Future<int> createTask({
    String title = 'Tarea',
    int reminderHour = 9,
    int reminderMinute = 0,
    String description = '',
    TaskImportance importance = TaskImportance.normal,
    TaskRepetition repetition = TaskRepetition.daily,
  }) {
    return dao.createTask(
      title: title,
      description: description,
      importance: importance,
      repetition: repetition,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
  }

  Future<void> taskWithHistory(
    List<DateTime> days, {
    TaskRepetition repetition = TaskRepetition.daily,
  }) async {
    final taskId = await createTask(repetition: repetition);
    for (final day in days) {
      await dao.toggleCompletion(taskId, day);
    }
  }

  test('creates a task and reads it back', () async {
    await createTask(
      title: 'Tomar agua',
      description: '2 litros',
      reminderHour: 9,
      reminderMinute: 30,
    );

    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks, hasLength(1));
    expect(tasks.first.task.title, 'Tomar agua');
    expect(tasks.first.task.description, '2 litros');
    expect(tasks.first.task.reminderHour, 9);
    expect(tasks.first.task.reminderMinute, 30);
    expect(tasks.first.currentStreak, 0);
    expect(tasks.first.completedToday, isFalse);
  });

  test('every task has a reminder', () async {
    await createTask(title: 'Con aviso', reminderHour: 7, reminderMinute: 45);

    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.task.reminderHour, 7);
    expect(tasks.first.task.reminderMinute, 45);
  });

  test('toggle marks and unmarks today', () async {
    final id = await createTask();

    await dao.toggleCompletion(id, DateTime.now());
    var tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.completedToday, isTrue);
    expect(tasks.first.currentStreak, 1);
    expect(tasks.first.totalCompletions, 1);

    await dao.toggleCompletion(id, DateTime.now());
    tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.completedToday, isFalse);
    expect(tasks.first.currentStreak, 0);
    expect(tasks.first.totalCompletions, 0);
  });

  test('current streak counts consecutive days ending today', () async {
    await taskWithHistory([daysAgo(2), daysAgo(1), daysAgo(0)]);

    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.currentStreak, 3);
  });

  test('streak survives when today is still pending', () async {
    await taskWithHistory([daysAgo(2), daysAgo(1)]);

    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.currentStreak, 2);
    expect(tasks.first.completedToday, isFalse);
  });

  test('streak resets after a missed day', () async {
    await taskWithHistory([daysAgo(3), daysAgo(2)]);

    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.currentStreak, 0);
  });

  test('best streak keeps the longest run', () async {
    await taskWithHistory([
      daysAgo(9),
      daysAgo(8),
      daysAgo(7),
      daysAgo(4),
      daysAgo(3),
      daysAgo(2),
      daysAgo(1),
      daysAgo(0),
    ]);

    // Runs of 3 days (9-7 days ago) and 5 days (4-0 days ago).
    final tasks = await dao.loadTasksWithStreaks();
    expect(tasks.first.bestStreak, 5);
    expect(tasks.first.currentStreak, 5);
    expect(tasks.first.totalCompletions, 8);
  });

  test('archived tasks disappear from the list', () async {
    final id = await createTask(title: 'Temporal');
    expect(await dao.loadTasksWithStreaks(), hasLength(1));

    await dao.archiveTask(id);
    expect(await dao.loadTasksWithStreaks(), isEmpty);
  });

  test('deleting a task removes its completions', () async {
    final id = await createTask(title: 'Temporal');
    await dao.toggleCompletion(id, DateTime.now());

    await dao.deleteTask(id);

    expect(await dao.loadTasksWithStreaks(), isEmpty);
    final remaining = await db.select(db.completions).get();
    expect(remaining, isEmpty);
  });

  test('the stream emits again when a completion is toggled', () async {
    final id = await createTask();

    final emissions = <int>[];
    final subscription = dao.watchTasksWithStreaks().listen((tasks) {
      emissions.add(tasks.first.currentStreak);
    });

    // Let the first emission arrive.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dao.toggleCompletion(id, DateTime.now());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await subscription.cancel();

    expect(emissions.first, 0);
    expect(emissions.last, 1);
  });

  test('day keys round-trip through the database', () async {
    final key = TaskDao.dayKey(DateTime(2026, 10, 21));
    expect(key, '2026-10-21');

    final parsed = TaskDao.parseDay(key);
    expect(parsed, DateTime(2026, 10, 21));
  });

  group('repetition', () {
    test('a new task is daily', () async {
      await createTask();

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.repetition, TaskRepetition.daily);
    });

    test('the repetition can be chosen when creating a task', () async {
      await createTask(repetition: TaskRepetition.alternate);
      await createTask(repetition: TaskRepetition.weekly);

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks[0].task.repetition, TaskRepetition.alternate);
      expect(tasks[1].task.repetition, TaskRepetition.weekly);
    });

    test('the repetition of a task can be changed', () async {
      final id = await createTask();

      await dao.updateRepetition(id, TaskRepetition.weekly);
      var tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.repetition, TaskRepetition.weekly);

      await dao.updateRepetition(id, TaskRepetition.daily);
      tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.repetition, TaskRepetition.daily);
    });

    test('an alternate task only comes due every other day', () async {
      await createTask(repetition: TaskRepetition.alternate);

      final tasks = await dao.loadTasksWithStreaks();
      final schedule = tasks.first.schedule;

      // The anchor is the day the task was created.
      expect(schedule.isDueOn(tasks.first.task.createdAt), isTrue);
      expect(
        schedule.isDueOn(tasks.first.task.createdAt.add(const Duration(days: 1))),
        isFalse,
      );
      expect(
        schedule.isDueOn(tasks.first.task.createdAt.add(const Duration(days: 2))),
        isTrue,
      );

      // The day after the creation is not due, so the task is not due today
      // unless today happens to be an even day.
      final today = DateTime.now();
      final daysSinceCreation = today.difference(tasks.first.task.createdAt).inDays;
      expect(schedule.isDueOn(today), daysSinceCreation.isEven);
    });

    test('a weekly task only comes due once a week', () async {
      await createTask(repetition: TaskRepetition.weekly);

      final tasks = await dao.loadTasksWithStreaks();
      final schedule = tasks.first.schedule;
      final created = tasks.first.task.createdAt;

      expect(schedule.isDueOn(created), isTrue);
      expect(
        schedule.isDueOn(created.add(const Duration(days: 6))),
        isFalse,
      );
      expect(
        schedule.isDueOn(created.add(const Duration(days: 7))),
        isTrue,
      );
    });

    test('the streak of an alternate task counts cycles, not days', () async {
      // A task created today, completed on the days that come due.
      final id = await createTask(repetition: TaskRepetition.alternate);
      final created = (await dao.loadTasksWithStreaks()).first.task.createdAt;

      await dao.toggleCompletion(id, created);
      await dao.toggleCompletion(id, created.add(const Duration(days: 2)));
      await dao.toggleCompletion(id, created.add(const Duration(days: 4)));

      final tasks = await dao.loadTasksWithStreaks();
      // Three cycles in a row.
      expect(tasks.first.currentStreak, 3);
      expect(tasks.first.bestStreak, 3);
      expect(tasks.first.totalCompletions, 3);
    });

    test('repetition is stored as a stable integer, not an enum index', () async {
      final id = await createTask(repetition: TaskRepetition.weekly);

      final raw = await db
          .customSelect(
            'SELECT repetition FROM streak_tasks WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle();

      expect(raw.read<int>('repetition'), TaskRepetition.weekly.dbValue);
    });

    test('an unknown stored repetition falls back to daily', () {
      expect(TaskRepetition.fromDb(0), TaskRepetition.daily);
      expect(TaskRepetition.fromDb(1), TaskRepetition.alternate);
      expect(TaskRepetition.fromDb(2), TaskRepetition.weekly);
      // A value written by a future version of the app must not crash.
      expect(TaskRepetition.fromDb(99), TaskRepetition.daily);
    });
  });

  group('completion log', () {
    test('every completion is stored as its own row', () async {
      final id = await createTask();

      await dao.toggleCompletion(id, daysAgo(3));
      await dao.toggleCompletion(id, daysAgo(2));
      await dao.toggleCompletion(id, daysAgo(1));

      final rows = await db.select(db.completions).get();
      expect(rows, hasLength(3));
      expect(
        rows.map((r) => r.day).toSet(),
        {
          TaskDao.dayKey(daysAgo(3)),
          TaskDao.dayKey(daysAgo(2)),
          TaskDao.dayKey(daysAgo(1)),
        },
      );
      // Each row also knows when it was written.
      expect(rows.every((r) => r.completedAt.year > 2000), isTrue);
    });

    test('the log is the source of the streak figures', () async {
      final id = await createTask();
      await dao.toggleCompletion(id, daysAgo(1));
      await dao.toggleCompletion(id, daysAgo(0));

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.totalCompletions, 2);
      expect(tasks.first.currentStreak, 2);
      expect(tasks.first.completedCycles, hasLength(2));
    });
  });

  group('importance', () {
    test('a new task defaults to normal importance', () async {
      await createTask();

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.importance, TaskImportance.normal);
      expect(tasks.first.task.importance.repeats, isFalse);
    });

    test('a task can be created as critical', () async {
      await createTask(importance: TaskImportance.critical);

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.importance, TaskImportance.critical);
      expect(tasks.first.task.importance.repeats, isTrue);
    });

    test('the importance of a task can be changed', () async {
      final id = await createTask();

      await dao.updateImportance(id, TaskImportance.critical);
      var tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.importance, TaskImportance.critical);

      await dao.updateImportance(id, TaskImportance.normal);
      tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.importance, TaskImportance.normal);
    });

    test('importance is stored as a stable integer, not an enum index', () async {
      final id = await createTask(importance: TaskImportance.critical);

      // Read the raw column, bypassing the converter.
      final raw = await db
          .customSelect(
            'SELECT importance FROM streak_tasks WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle();

      expect(raw.read<int>('importance'), TaskImportance.critical.dbValue);
    });

    test('an unknown stored importance falls back to normal', () {
      expect(TaskImportance.fromDb(0), TaskImportance.normal);
      expect(TaskImportance.fromDb(1), TaskImportance.critical);
      expect(TaskImportance.fromDb(2), TaskImportance.important);
      // A value written by a future version of the app must not crash.
      expect(TaskImportance.fromDb(99), TaskImportance.normal);
    });

    test('the stored values of the levels never change', () {
      // A task stored before the `important` level existed keeps its meaning:
      // 0 has always been normal and 1 has always been critical.
      expect(TaskImportance.normal.dbValue, 0);
      expect(TaskImportance.critical.dbValue, 1);
      expect(TaskImportance.important.dbValue, 2);
    });

    test('a task stored as critical is still critical', () async {
      // Simulates a row written before the `important` level was added.
      final id = await createTask();
      await db.customStatement(
        'UPDATE streak_tasks SET importance = 1 WHERE id = $id',
      );

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.task.importance, TaskImportance.critical);
    });
  });
}
