import 'package:flutter/material.dart';

import '../data/task_dao.dart';
import '../data/task_importance.dart';
import '../theme.dart';
import '../widgets/flame_logo.dart';
import '../widgets/importance_picker.dart';
import '../widgets/importance_visuals.dart';

/// Detail view of a single task.
///
/// It shows the name, the description, how many times the task has been
/// completed and offers the destructive action, which asks for a
/// confirmation before deleting anything.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.tasks,
    required this.taskId,
    required this.onDelete,
    this.onImportanceChanged,
  });

  /// The stream of tasks the screen listens to.
  ///
  /// It comes from the outside so the screen does not depend on the
  /// database, which keeps it testable on its own.
  final Stream<List<TaskWithStreaks>> tasks;

  final int taskId;

  /// Deletes the task with the given id.
  final Future<void> Function(int taskId) onDelete;

  /// Changes the importance of a task. When null the level is read-only.
  final Future<void> Function(int taskId, TaskImportance importance)?
  onImportanceChanged;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  /// Deletes the task, but only after the user confirms it.
  Future<void> _deleteTask(TaskWithStreaks entry) async {
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar la tarea?'),
        content: Text(
          'Se eliminará "${entry.task.title}" junto con su historial de '
          '${entry.totalCompletions} completados. Esta acción no se puede '
          'deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.onDelete(widget.taskId);
    if (mounted) Navigator.of(context).pop();
  }

  /// Opens the importance picker of the task.
  Future<void> _editImportance(TaskWithStreaks entry) async {
    final selected = await showImportancePicker(
      context,
      current: entry.task.importance,
      subtitle: entry.task.title,
    );

    if (selected != null && selected != entry.task.importance) {
      await widget.onImportanceChanged?.call(entry.task.id, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la tarea')),
      body: StreamBuilder<List<TaskWithStreaks>>(
        stream: widget.tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _MissingTask(message: 'No se pudo cargar la tarea');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          TaskWithStreaks? entry;
          for (final candidate in snapshot.data!) {
            if (candidate.task.id == widget.taskId) {
              entry = candidate;
              break;
            }
          }

          if (entry == null) {
            return const _MissingTask(message: 'La tarea ya no existe');
          }

          return _DetailBody(
            entry: entry,
            onDelete: () => _deleteTask(entry!),
            onEditImportance: widget.onImportanceChanged == null
                ? null
                : () => _editImportance(entry!),
          );
        },
      ),
    );
  }
}

/// The content of the detail view.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.entry,
    required this.onDelete,
    this.onEditImportance,
  });

  final TaskWithStreaks entry;
  final VoidCallback onDelete;

  /// Opens the importance editor. When null the level is read-only.
  final VoidCallback? onEditImportance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          task.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _StreakCard(entry: entry),
        const SizedBox(height: 12),
        _MetadataCard(entry: entry, onEditImportance: onEditImportance),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar tarea'),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Card with the streak figures of the task.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.entry});

  final TaskWithStreaks entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final alive = entry.currentStreak > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FlameLogo(
                  size: 38,
                  color: alive
                      ? StreaksTheme.flameOrange
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Racha actual',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.currentStreak == 1
                            ? '1 vez'
                            : '${entry.currentStreak} veces',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: alive
                              ? StreaksTheme.flameOrange
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Mejor racha',
                    value: '${entry.bestStreak}',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Completados',
                    value: '${entry.totalCompletions}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single figure of the streak card.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Card with the schedule of the task.
class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.entry, this.onEditImportance});

  final TaskWithStreaks entry;
  final VoidCallback? onEditImportance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;

    final rows = <(IconData, String, String)>[
      (
        task.importance.icon,
        task.importance.label,
        task.importance.intervalLabel,
      ),
      (
        Icons.notifications_active_outlined,
        'Recordatorio',
        '${task.reminderHour.toString().padLeft(2, '0')}:'
            '${task.reminderMinute.toString().padLeft(2, '0')}',
      ),
      (Icons.event_repeat_outlined, 'Repetición', task.repetition.label),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                // The importance is the only row that can be changed, and it
                // is the first one.
                onTap: i == 0 ? onEditImportance : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        rows[i].$1,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        rows[i].$3,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (i == 0 && onEditImportance != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when the task is gone or cannot be read.
class _MissingTask extends StatelessWidget {
  const _MissingTask({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
