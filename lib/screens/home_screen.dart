import 'package:flutter/material.dart';

import '../data/dates.dart';
import '../data/database.dart';
import '../data/task_dao.dart';
import '../data/task_importance.dart';
import '../data/task_repetition.dart';
import '../notifications/app_lifecycle_observer.dart';
import '../notifications/notification_service.dart';
import '../notifications/reminder_scheduler.dart';
import '../theme.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/flame_logo.dart';
import '../widgets/section_header.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

/// First screen of the app: the list of recurring tasks and their streaks.
///
/// The list is driven by a Drift stream, so every write to the database
/// (toggling a completion, adding or deleting a task) refreshes the UI
/// automatically.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.database, this.notifications});

  final AppDatabase database;

  /// The service used to schedule the reminders. Optional so the screen can
  /// be rendered in tests without touching the notification plugin.
  final NotificationService? notifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TaskDao _dao = TaskDao(widget.database);
  late final Stream<List<TaskWithStreaks>> _tasks = _dao
      .watchTasksWithStreaks();

  late final NotificationService _notifications =
      widget.notifications ?? NotificationService();

  late final ReminderScheduler _scheduler = ReminderScheduler(
    service: _notifications,
    tasks: () => _dao.loadTasksWithStreaks(),
  );

  late final AppLifecycleObserver _lifecycleObserver = AppLifecycleObserver(
    onResumed: _onResumed,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _bootstrapNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  /// Asks for the notification permission and schedules the reminders.
  Future<void> _bootstrapNotifications() async {
    try {
      await _notifications.initialize();
      final granted = await _notifications.requestPermission();
      if (granted) await _scheduler.rescheduleAll();
    } on Object {
      // Notifications are a nice-to-have; the app must work without them.
    }
  }

  /// Re-schedules the reminders when the app comes back to the foreground,
  /// so a critical task keeps nagging and a completed one stops.
  Future<void> _onResumed() async {
    try {
      if (_notifications.hasPermission) {
        await _scheduler.rescheduleAll();
      }
    } on Object {
      // Ignore failures, the reminders are re-scheduled on the next resume.
    }
  }

  Future<void> _addTask({
    required String title,
    required String description,
    required TaskImportance importance,
    required TaskRepetition repetition,
    required int reminderHour,
    required int reminderMinute,
  }) async {
    await _dao.createTask(
      title: title,
      description: description,
      importance: importance,
      repetition: repetition,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
    await _reschedule();
  }

  Future<void> _toggleTask(int taskId) async {
    await _dao.toggleCompletion(taskId, DateTime.now());
    await _reschedule();
  }

  /// Re-schedules the reminders after a change in the tasks.
  Future<void> _reschedule() async {
    try {
      if (_notifications.hasPermission) {
        await _scheduler.rescheduleAll();
      }
    } on Object {
      // Ignore failures; the next resume re-schedules.
    }
  }

  /// Opens the detail view of a task.
  Future<void> _openDetail(TaskWithStreaks entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(
          tasks: _dao.watchTasksWithStreaks(),
          taskId: entry.task.id,
          onDelete: _deleteTask,
          onImportanceChanged: _changeImportance,
        ),
      ),
    );
    // The detail view may have deleted the task, so the reminders are
    // re-scheduled when it closes.
    await _reschedule();
  }

  /// Changes the importance of a task.
  Future<void> _changeImportance(int taskId, TaskImportance importance) async {
    await _dao.updateImportance(taskId, importance);
    await _reschedule();
  }

  /// Deletes a task and drops its pending reminders.
  Future<void> _deleteTask(int taskId) async {
    await _dao.deleteTask(taskId);
    await _reschedule();
  }

  /// Builds the card of a task.
  Widget _card(TaskWithStreaks entry, {String? dueLabel}) {
    return TaskCard(
      entry: entry,
      dueLabel: dueLabel,
      onToggle: () => _toggleTask(entry.task.id),
      onOpenDetail: () => _openDetail(entry),
    );
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => AddTaskSheet(onSubmit: _addTask),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [FlameLogo(size: 30), SizedBox(width: 10), Text('Streaks')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
      body: StreamBuilder<List<TaskWithStreaks>>(
        stream: _tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;
          final today = DateTime.now();

          // The tasks of today come first, then the ones that come due on
          // the coming days, ordered by the day they are due on.
          final forToday = tasks.where((t) => t.isForToday).toList();
          final comingUp = tasks.where((t) => !t.isForToday).toList()
            ..sort((a, b) => a.nextDueDay.compareTo(b.nextDueDay));

          final doneCount = forToday.where((t) => t.isCycleDone).length;

          return Column(
            children: [
              if (tasks.isNotEmpty)
                _ProgressHeader(done: doneCount, total: forToday.length),
              Expanded(
                child: tasks.isEmpty
                    ? _EmptyState(onAdd: _openAddSheet)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        children: [
                          if (forToday.isNotEmpty) ...[
                            SectionHeader(
                              title: 'Hoy',
                              count: forToday.length,
                              icon: Icons.today_outlined,
                            ),
                            for (final entry in forToday) ...[
                              _card(entry),
                              const SizedBox(height: 12),
                            ],
                          ],
                          if (comingUp.isNotEmpty) ...[
                            SectionHeader(
                              title: 'Próximos días',
                              count: comingUp.length,
                              icon: Icons.event_outlined,
                            ),
                            for (final entry in comingUp) ...[
                              _card(
                                entry,
                                dueLabel: relativeDayLabel(
                                  entry.nextDueDay,
                                  today,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Header showing how much of today's routine is already done.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone = done == total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: StreaksTheme.creamDeep,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$done/$total hoy',
              style: theme.textTheme.labelLarge?.copyWith(
                color: StreaksTheme.ember,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              allDone ? '¡Rutina completa! 🔥' : 'Mantén la racha viva',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlameLogo(size: 72),
            const SizedBox(height: 16),
            Text(
              'Empieza tu primera racha',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tareas repetitivas, complétalas cada día y mantén viva tu racha.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar la base de datos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
