/// Domain model for a recurring habit tracked with a streak.
class StreakTask {
  StreakTask({
    required this.id,
    required this.title,
    this.description = '',
    this.reminderHour,
    this.reminderMinute,
    this.createdAt = '',
    Map<DateTime, bool>? completions,
  }) : completions = completions ?? <DateTime, bool>{};

  final String id;
  final String title;
  final String description;

  /// Local time of the daily reminder. `null` means no reminder scheduled.
  final int? reminderHour;
  final int? reminderMinute;

  /// ISO date (yyyy-MM-dd) the task was created, used for streak math.
  final String createdAt;

  /// Map of day -> whether the task was completed on that day.
  final Map<DateTime, bool> completions;

  bool get hasReminder => reminderHour != null && reminderMinute != null;

  bool isCompletedOn(DateTime day) => completions[_key(day)] ?? false;

  void toggle(DateTime day) {
    final key = _key(day);
    final current = completions[key] ?? false;
    if (current) {
      completions.remove(key);
    } else {
      completions[key] = true;
    }
  }

  /// Number of consecutive completed days ending today (or yesterday, if today
  /// has not been completed yet and the streak is still alive).
  int currentStreak([DateTime? now]) {
    final today = _dayOnly(now ?? DateTime.now());
    var streak = 0;
    var cursor = today;

    // Today not completed yet: the streak may still be alive from yesterday.
    if (!isCompletedOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!isCompletedOn(cursor)) return 0;
    }

    while (isCompletedOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Best streak ever achieved.
  int bestStreak() {
    if (completions.isEmpty) return 0;
    final days = completions.keys.where((d) => completions[d] == true).toList()
      ..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      if (previous != null && day.difference(previous).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  /// Total number of days completed.
  int totalCompletions() =>
      completions.values.where((done) => done).length;

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _key(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
