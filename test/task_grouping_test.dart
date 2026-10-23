import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/dates.dart';
import 'package:streaks/data/database.dart';
import 'package:streaks/data/task_dao.dart';
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

  /// The calendar day [n] days from today.
  DateTime daysFromNow(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + n);
  }

  int todayNumber() => dayNumber(DateTime.now());

  Future<int> createTask({
    String title = 'Tarea',
    TaskRepetition repetition = TaskRepetition.daily,
    DateTime? createdAt,
  }) {
    return dao.createTask(
      title: title,
      repetition: repetition,
      reminderHour: 9,
      reminderMinute: 0,
      createdAt: createdAt,
    );
  }

  group('grouping by day', () {
    test('a daily task comes due today', () async {
      await createTask();

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.isForToday, isTrue);
      expect(dayNumber(tasks.first.nextDueDay), todayNumber());
    });

    test('a weekly task created a week ago comes due today', () async {
      await createTask(
        repetition: TaskRepetition.weekly,
        createdAt: daysAgo(7),
      );

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.isForToday, isTrue);
      expect(dayNumber(tasks.first.nextDueDay), todayNumber());
    });

    test('a task due today stays in today even when it is done', () async {
      final id = await createTask(
        repetition: TaskRepetition.weekly,
        createdAt: daysAgo(7),
      );
      await dao.toggleCompletion(id, DateTime.now());

      final tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.isCycleDone, isTrue);
      // It is today's task, so it stays in the first group, done.
      expect(tasks.first.isForToday, isTrue);
    });

    test('a task between its due days waits for the coming days', () async {
      // Created eight days ago, so its last due day was yesterday and the
      // next one is in six days.
      final id = await createTask(
        repetition: TaskRepetition.weekly,
        createdAt: daysAgo(8),
      );

      var tasks = await dao.loadTasksWithStreaks();
      // Its cycle is still open, so it is a task for today.
      expect(tasks.first.isForToday, isTrue);
      expect(tasks.first.isCycleDone, isFalse);

      // Once the cycle is done it moves to the coming days.
      await dao.toggleCompletion(id, daysAgo(1));
      tasks = await dao.loadTasksWithStreaks();
      expect(tasks.first.isCycleDone, isTrue);
      expect(tasks.first.isForToday, isFalse);
      expect(dayNumber(tasks.first.nextDueDay), dayNumber(daysFromNow(6)));
    });

    test(
      'an alternate task on its off day waits for the coming days',
      () async {
        // Created yesterday, so today is not a due day for it.
        final id = await createTask(
          repetition: TaskRepetition.alternate,
          createdAt: daysAgo(1),
        );

        var tasks = await dao.loadTasksWithStreaks();
        expect(tasks.first.isForToday, isTrue);
        // Today is not a due day for it, so the next one is tomorrow.
        expect(dayNumber(tasks.first.nextDueDay), dayNumber(daysFromNow(1)));

        // Once its cycle is done it moves to the coming days.
        await dao.toggleCompletion(id, daysAgo(1));
        tasks = await dao.loadTasksWithStreaks();
        expect(tasks.first.isCycleDone, isTrue);
        expect(tasks.first.isForToday, isFalse);
        expect(dayNumber(tasks.first.nextDueDay), dayNumber(daysFromNow(1)));
      },
    );

    test('every task ends up in one of the two groups', () async {
      await createTask(title: 'Diaria');
      final id = await createTask(
        title: 'Semanal',
        repetition: TaskRepetition.weekly,
        createdAt: daysAgo(8),
      );
      await dao.toggleCompletion(id, daysAgo(1));

      final tasks = await dao.loadTasksWithStreaks();
      final forToday = tasks.where((t) => t.isForToday).length;
      final comingUp = tasks.length - forToday;

      expect(forToday + comingUp, tasks.length);
      expect(tasks.any((t) => !t.isForToday), isTrue);
    });
  });
}
