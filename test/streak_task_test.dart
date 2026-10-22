import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/models/streak_task.dart';

void main() {
  StreakTask taskWith(List<DateTime> days) {
    return StreakTask(
      id: 't',
      title: 'Test task',
      completions: {for (final d in days) d: true},
    );
  }

  test('toggle marks and unmarks a day', () {
    final task = StreakTask(id: 't', title: 'Test task');
    final today = DateTime(2026, 10, 21);

    expect(task.isCompletedOn(today), isFalse);
    task.toggle(today);
    expect(task.isCompletedOn(today), isTrue);
    task.toggle(today);
    expect(task.isCompletedOn(today), isFalse);
  });

  test('current streak counts consecutive days ending today', () {
    final task = taskWith([
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 21),
    ]);

    expect(task.currentStreak(DateTime(2026, 10, 21)), 3);
  });

  test('streak survives when today is still pending', () {
    final task = taskWith([
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 20),
    ]);

    expect(task.currentStreak(DateTime(2026, 10, 21)), 2);
  });

  test('streak resets after a missed day', () {
    final task = taskWith([
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 16),
    ]);

    // Yesterday (10-20) is missing, so the streak is dead.
    expect(task.currentStreak(DateTime(2026, 10, 21)), 0);
  });

  test('streak restarts from the last completed day after a gap', () {
    final task = taskWith([
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 16),
      DateTime(2026, 10, 20),
    ]);

    expect(task.currentStreak(DateTime(2026, 10, 21)), 1);
  });

  test('best streak keeps the longest run', () {
    final task = taskWith([
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 2),
      DateTime(2026, 10, 3),
      DateTime(2026, 10, 10),
    ]);

    expect(task.bestStreak(), 3);
    expect(task.totalCompletions(), 4);
  });
}
