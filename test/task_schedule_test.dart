import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/task_repetition.dart';
import 'package:streaks/data/task_schedule.dart';

void main() {
  final anchor = DateTime(2026, 10, 1);

  TaskSchedule schedule(TaskRepetition repetition) =>
      TaskSchedule(anchor: anchor, repetition: repetition);

  group('daily', () {
    final s = schedule(TaskRepetition.daily);

    test('every day is due', () {
      expect(s.isDueOn(DateTime(2026, 10, 1)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 2)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 20)), isTrue);
    });

    test('each day is its own cycle', () {
      expect(s.cycleOf(DateTime(2026, 10, 1)), 0);
      expect(s.cycleOf(DateTime(2026, 10, 2)), 1);
      expect(s.cycleOf(DateTime(2026, 10, 20)), 19);
    });

    test('the next due day is today', () {
      expect(s.nextDueDay(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    });
  });

  group('alternate', () {
    final s = schedule(TaskRepetition.alternate);

    test('only every other day is due', () {
      expect(s.isDueOn(DateTime(2026, 10, 1)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 2)), isFalse);
      expect(s.isDueOn(DateTime(2026, 10, 3)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 4)), isFalse);
    });

    test('a two day window is one cycle', () {
      expect(s.cycleOf(DateTime(2026, 10, 1)), 0);
      expect(s.cycleOf(DateTime(2026, 10, 2)), 0);
      expect(s.cycleOf(DateTime(2026, 10, 3)), 1);
      expect(s.cycleOf(DateTime(2026, 10, 4)), 1);
    });

    test('the next due day skips the off days', () {
      expect(s.nextDueDay(DateTime(2026, 10, 2)), DateTime(2026, 10, 3));
      expect(s.nextDueDay(DateTime(2026, 10, 4)), DateTime(2026, 10, 5));
    });
  });

  group('weekly', () {
    final s = schedule(TaskRepetition.weekly);

    test('only the same weekday is due', () {
      expect(s.isDueOn(DateTime(2026, 10, 1)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 2)), isFalse);
      expect(s.isDueOn(DateTime(2026, 10, 8)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 9)), isFalse);
    });

    test('a whole week is one cycle', () {
      expect(s.cycleOf(DateTime(2026, 10, 1)), 0);
      expect(s.cycleOf(DateTime(2026, 10, 7)), 0);
      expect(s.cycleOf(DateTime(2026, 10, 8)), 1);
    });
  });

  test('days before the anchor belong to negative cycles', () {
    final s = schedule(TaskRepetition.daily);
    expect(s.cycleOf(DateTime(2026, 9, 30)), -1);
    expect(s.isDueOn(DateTime(2026, 9, 30)), isFalse);
  });

  group('streaks', () {
    test('a daily streak counts consecutive days', () {
      final s = schedule(TaskRepetition.daily);
      final completed = {0, 1, 2};

      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 3)),
        3,
      );
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 4)),
        3,
      );
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 5)),
        0,
      );
    });

    test('an alternate streak counts consecutive cycles, not days', () {
      final s = schedule(TaskRepetition.alternate);
      // Cycles 0, 1 and 2 were completed, so the task is on a roll.
      final completed = {0, 1, 2};

      // 2026-10-05 is the due day of cycle 2.
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 5)),
        3,
      );
      // 2026-10-06 is an off day, the streak is still alive.
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 6)),
        3,
      );
      // 2026-10-07 is the due day of cycle 3, which is still pending.
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 7)),
        3,
      );
      // The cycle after that was missed, so the streak is over.
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 9)),
        0,
      );
    });

    test('a weekly streak counts consecutive weeks', () {
      final s = schedule(TaskRepetition.weekly);
      final completed = {0, 1, 2};

      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 15)),
        3,
      );
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 22)),
        3,
      );
      expect(
        s.currentStreak(completed: completed, today: DateTime(2026, 10, 29)),
        0,
      );
    });

    test('the best streak is the longest run of cycles', () {
      final s = schedule(TaskRepetition.daily);
      expect(s.bestStreak(completed: {0, 1, 5, 6, 7, 8}), 4);
      expect(s.bestStreak(completed: {}), 0);
    });
  });

  group('next reminder', () {
    test('uses today when the time has not passed', () {
      final s = schedule(TaskRepetition.daily);
      final at = s.nextReminderAt(
        hour: 18,
        minute: 0,
        now: DateTime(2026, 10, 5, 9),
      );
      expect(at, DateTime(2026, 10, 5, 18));
    });

    test('moves to the next due day when the time has passed', () {
      final s = schedule(TaskRepetition.daily);
      final at = s.nextReminderAt(
        hour: 9,
        minute: 0,
        now: DateTime(2026, 10, 5, 18),
      );
      expect(at, DateTime(2026, 10, 6, 9));
    });

    test('skips the days the task does not come due on', () {
      final s = schedule(TaskRepetition.alternate);
      // 2026-10-02 is an off day, so the reminder waits for 10-03.
      final at = s.nextReminderAt(
        hour: 9,
        minute: 0,
        now: DateTime(2026, 10, 2, 10),
      );
      expect(at, DateTime(2026, 10, 3, 9));
    });
  });
}
