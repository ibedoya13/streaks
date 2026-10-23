import 'package:flutter/material.dart';

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
import '../widgets/importance_selector.dart';
import '../widgets/task_card.dart';

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

  Future<void> _deleteTask(int taskId) async {
    await _dao.deleteTask(taskId);
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

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => AddTaskSheet(onSubmit: _addTask),
    );
  }

  /// Opens the importance editor for a task.
  Future<void> _editImportance(TaskWithStreaks entry) async {
    final selected = await showModalBottomSheet<TaskImportance>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) {
        var current = entry.task.importance;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              // Scrollable for the same reason as the new-task sheet: with
              // a tall keyboard the available height can be too small.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Importancia',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.task.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ImportanceSelector(
                      value: current,
                      onChanged: (value) {
                        setSheetState(() => current = value);
                        Navigator.of(sheetContext).pop(value);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && selected != entry.task.importance) {
      await _dao.updateImportance(entry.task.id, selected);
      await _reschedule();
    }
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
          final doneCount = tasks.where((t) => t.completedToday).length;

          return Column(
            children: [
              if (tasks.isNotEmpty)
                _ProgressHeader(done: doneCount, total: tasks.length),
              Expanded(
                child: tasks.isEmpty
                    ? _EmptyState(onAdd: _openAddSheet)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = tasks[index];
                          return TaskCard(
                            entry: entry,
                            onToggle: () => _toggleTask(entry.task.id),
                            onDelete: () => _deleteTask(entry.task.id),
                            onEditImportance: () => _editImportance(entry),
                          );
                        },
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
