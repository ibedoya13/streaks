import '../data/task_dao.dart';
import '../data/task_importance.dart';
import 'notification_service.dart';

/// Keeps the operating system's scheduled notifications in sync with the
/// tasks stored in the database.
///
/// The rules are:
///
///  * a normal task gets a single reminder at its scheduled time;
///  * a critical task repeats every [NotificationService.criticalInterval]
///    until the user marks it as done;
///  * a task that is already done for today gets no reminder at all.
class ReminderScheduler {
  ReminderScheduler({required this.service, required this.tasks});

  final NotificationService service;

  /// Loads the current tasks. Injected so the scheduler can be tested
  /// without a database.
  final Future<List<TaskWithStreaks>> Function() tasks;

  /// Re-schedules every reminder from scratch.
  ///
  /// Cancelling everything first keeps the state consistent even if a task
  /// was deleted, completed or had its importance changed.
  Future<void> rescheduleAll() async {
    await service.initialize();
    if (!service.hasPermission) return;

    final current = await tasks();
    final liveTaskIds = current.map((entry) => entry.task.id).toSet();

    // Cancel the reminders of tasks that no longer exist. They are not in
    // the current list, so they would otherwise keep firing forever.
    final pending = await service.pending();
    final orphans = <int>{};
    for (final request in pending) {
      final taskId = request.id ~/ NotificationService.idStride;
      if (!liveTaskIds.contains(taskId)) orphans.add(taskId);
    }
    for (final taskId in orphans) {
      await service.cancelTask(taskId);
    }

    // Remove the reminders of tasks that no longer need them.
    final keep = <int>{};
    for (final entry in current) {
      if (_needsReminder(entry)) {
        keep.add(entry.task.id);
      }
    }

    for (final entry in current) {
      if (!keep.contains(entry.task.id)) {
        await service.cancelTask(entry.task.id);
      }
    }

    for (final entry in current) {
      if (!keep.contains(entry.task.id)) continue;
      await _schedule(entry);
    }
  }

  /// Whether a task still needs a reminder scheduled.
  ///
  /// A task that is already done for the current cycle needs no reminder:
  /// the next one is scheduled when the app comes back to the foreground.
  bool _needsReminder(TaskWithStreaks entry) {
    final schedule = entry.schedule;
    final today = DateTime.now();

    // The cycle the task is in right now.
    final cycle = schedule.cycleOf(today);
    if (entry.completedCycles.contains(cycle)) return false;

    return true;
  }

  Future<void> _schedule(TaskWithStreaks entry) async {
    final task = entry.task;
    await service.scheduleTask(
      taskId: task.id,
      title: task.title,
      body: _bodyFor(entry),
      hour: task.reminderHour,
      minute: task.reminderMinute,
      importance: task.importance,
      schedule: entry.schedule,
    );
  }

  /// The text shown in the notification.
  String _bodyFor(TaskWithStreaks entry) {
    final task = entry.task;
    final streak = entry.currentStreak;

    if (task.importance == TaskImportance.critical) {
      return streak > 0
          ? 'Racha de $streak días. No dejes que se rompa.'
          : 'Completa esta tarea para no romper tu racha.';
    }
    if (task.importance == TaskImportance.important) {
      return streak > 0
          ? 'Racha de $streak días. Sigue así.'
          : 'Completa esta tarea para empezar tu racha.';
    }
    if (task.description.isNotEmpty) return task.description;
    return 'Es hora de ${task.title.toLowerCase()}';
  }

  /// The importance levels the app currently knows about.
  static List<TaskImportance> get levels => TaskImportance.values;
}
