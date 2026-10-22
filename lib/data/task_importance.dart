import 'package:drift/drift.dart';

/// How important a task is, which in turn drives how insistent the
/// notifications for it will be.
///
/// The levels are stored by an explicit numeric value rather than by enum
/// index, so adding or reordering levels later never invalidates the data
/// already in the database.
enum TaskImportance {
  /// A routine task. One reminder at the scheduled time.
  normal(
    dbValue: 0,
    label: 'Normal',
    description: 'Un aviso a la hora programada',
  ),

  /// A task that must not be missed. Its reminders escalate and repeat.
  critical(
    dbValue: 1,
    label: 'Crítico',
    description: 'Avisos repetidos hasta completarlo',
  );

  const TaskImportance({
    required this.dbValue,
    required this.label,
    required this.description,
  });

  /// The value stored in the database.
  final int dbValue;

  /// The stored value of [normal], usable in a const context.
  ///
  /// Needed because a table default has to be a compile-time constant, and
  /// reading an instance field of an enum is not const-evaluable.
  static const int normalDbValue = 0;

  /// Short name shown in the UI.
  final String label;

  /// One-line explanation of what this level means for reminders.
  final String description;

  /// Whether this level escalates its reminders.
  bool get isEscalating => this == TaskImportance.critical;

  /// Maps a stored value back to a level, falling back to [normal] for
  /// values written by a future version of the app.
  static TaskImportance fromDb(int value) {
    for (final level in TaskImportance.values) {
      if (level.dbValue == value) return level;
    }
    return TaskImportance.normal;
  }
}

/// Converts [TaskImportance] to and from its stored integer.
class TaskImportanceConverter extends TypeConverter<TaskImportance, int> {
  const TaskImportanceConverter();

  @override
  TaskImportance fromSql(int fromDb) => TaskImportance.fromDb(fromDb);

  @override
  int toSql(TaskImportance value) => value.dbValue;
}
