import 'task_repetition.dart';

/// The calendar of a recurring task.
///
/// The schedule is anchored on the day the task was created. From that
/// anchor, the task comes due every [TaskRepetition.periodInDays] days.
///
/// A day belongs to a *cycle*: the cycle that contains it since the last due
/// day. For a daily task a cycle is a single day, for an alternate task it
/// is a two-day window, and for a weekly task a seven-day one. A streak is
/// then a run of consecutive cycles in which the task was completed.
class TaskSchedule {
  const TaskSchedule({required this.anchor, required this.repetition});

  /// The local day the schedule starts on.
  final DateTime anchor;

  /// How often the task comes due.
  final TaskRepetition repetition;

  /// How many days pass between two due days.
  int get periodInDays => repetition.periodInDays;

  /// The number of days between the anchor and [day].
  int daysSinceAnchor(DateTime day) =>
      _dayNumber(day) - _dayNumber(anchor);

  /// The cycle [day] belongs to.
  ///
  /// Days before the anchor get negative cycles, which are ignored when
  /// counting streaks.
  int cycleOf(DateTime day) {
    final diff = daysSinceAnchor(day);
    // Floor division, so that a day before the anchor lands in a negative
    // cycle instead of the cycle zero.
    return (diff - diff % periodInDays) ~/ periodInDays;
  }

  /// Whether the task is due on [day].
  bool isDueOn(DateTime day) {
    if (daysSinceAnchor(day) < 0) return false;
    return daysSinceAnchor(day) % periodInDays == 0;
  }

  /// The due day that opens [cycle].
  DateTime dueDayOfCycle(int cycle) =>
      DateTime(anchor.year, anchor.month, anchor.day + cycle * periodInDays);

  /// The first day on or after [from] on which the task is due.
  DateTime nextDueDay(DateTime from) {
    var day = DateTime(from.year, from.month, from.day);
    while (!isDueOn(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  /// The next moment the reminder should fire, given the reminder time.
  ///
  /// Returns the due day at [hour]:[minute], moving to a later due day when
  /// the time has already passed.
  DateTime nextReminderAt({
    required int hour,
    required int minute,
    required DateTime now,
  }) {
    var day = DateTime(now.year, now.month, now.day);
    var at = DateTime(day.year, day.month, day.day, hour, minute);

    if (at.isAfter(now)) {
      // It might still be a day the task is not due on.
      if (isDueOn(day)) return at;
    }

    // Move to the next due day whose time has not passed yet.
    var candidate = nextDueDay(day.add(const Duration(days: 1)));
    while (!DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      hour,
      minute,
    ).isAfter(now)) {
      candidate = candidate.add(Duration(days: periodInDays));
    }
    return DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      hour,
      minute,
    );
  }

  /// The number of consecutive cycles ending at [cycle] that were completed.
  ///
  /// [completed] holds the cycles in which the task was completed.
  int streakEndingAt({
    required Set<int> completed,
    required int cycle,
  }) {
    var streak = 0;
    var cursor = cycle;
    while (completed.contains(cursor)) {
      streak++;
      cursor--;
    }
    return streak;
  }

  /// The longest run of consecutive completed cycles.
  int bestStreak({required Set<int> completed}) {
    if (completed.isEmpty) return 0;

    var best = 0;
    var run = 0;
    var previous = -1;

    final cycles = completed.toList()..sort();
    for (final cycle in cycles) {
      if (previous != -1 && cycle == previous + 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      previous = cycle;
    }
    return best;
  }

  /// The current streak of the task.
  ///
  /// The streak stays alive while the task is still pending, so it falls
  /// back to the previous cycle when today is due but not done yet.
  int currentStreak({
    required Set<int> completed,
    required DateTime today,
  }) {
    final cycle = cycleOf(today);
    if (completed.contains(cycle)) {
      return streakEndingAt(completed: completed, cycle: cycle);
    }
    if (isDueOn(today)) {
      return streakEndingAt(completed: completed, cycle: cycle - 1);
    }
    return 0;
  }

  /// The number of days since the epoch for the calendar day of [date].
  ///
  /// The date is read as a plain calendar date in UTC, so a daylight saving
  /// change never shifts the result by a day.
  static int _dayNumber(DateTime date) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}
