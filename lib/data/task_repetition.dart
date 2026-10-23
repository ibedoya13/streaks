import 'package:drift/drift.dart';

/// How often a task comes due.
///
/// The repetition defines the schedule of a task: which days it is due and
/// therefore how its streak is counted.
enum TaskRepetition {
  /// The task is due every single day.
  daily(
    dbValue: 0,
    label: 'Diaria',
    description: 'Todos los días',
    periodInDays: 1,
  ),

  /// The task is due every other day.
  alternate(
    dbValue: 1,
    label: 'Alterna',
    description: 'Día por medio',
    periodInDays: 2,
  ),

  /// The task is due once a week.
  weekly(
    dbValue: 2,
    label: 'Semanal',
    description: 'Una vez por semana',
    periodInDays: 7,
  );

  const TaskRepetition({
    required this.dbValue,
    required this.label,
    required this.description,
    required this.periodInDays,
  });

  /// The value stored in the database.
  final int dbValue;

  /// The stored value of [daily], usable in a const context.
  ///
  /// Needed because a table default has to be a compile-time constant, and
  /// reading an instance field of an enum is not const-evaluable.
  static const int dailyDbValue = 0;

  /// Short name shown in the UI.
  final String label;

  /// One-line explanation of the schedule.
  final String description;

  /// How many days pass between two due days.
  final int periodInDays;

  /// Maps a stored value back to a repetition, falling back to [daily] for
  /// values written by a future version of the app.
  static TaskRepetition fromDb(int value) {
    for (final repetition in TaskRepetition.values) {
      if (repetition.dbValue == value) return repetition;
    }
    return TaskRepetition.daily;
  }
}

/// Converts [TaskRepetition] to and from its stored integer.
class TaskRepetitionConverter extends TypeConverter<TaskRepetition, int> {
  const TaskRepetitionConverter();

  @override
  TaskRepetition fromSql(int fromDb) => TaskRepetition.fromDb(fromDb);

  @override
  int toSql(TaskRepetition value) => value.dbValue;
}
