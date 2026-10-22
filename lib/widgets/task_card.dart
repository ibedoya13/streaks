import 'package:flutter/material.dart';

import '../models/streak_task.dart';

/// Card representing a single recurring task and its live streak.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final StreakTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final streak = task.currentStreak();
    final doneToday = task.isCompletedOn(DateTime.now());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              _StreakBadge(streak: streak, doneToday: doneToday),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: doneToday
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: doneToday
                            ? scheme.onSurface.withValues(alpha: 0.6)
                            : scheme.onSurface,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          streak == 1 ? '1 día' : '$streak días',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.hasReminder) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(task.reminderHour!, task.reminderMinute!),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: scheme.onSurface.withValues(alpha: 0.35),
                tooltip: 'Eliminar tarea',
              ),
              Checkbox(
                value: doneToday,
                onChanged: (_) => onToggle(),
                shape: const CircleBorder(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Circular badge that visualises the current streak length.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak, required this.doneToday});

  final int streak;
  final bool doneToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = doneToday ? scheme.primary : scheme.outline;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: doneToday
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$streak',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: doneToday ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
