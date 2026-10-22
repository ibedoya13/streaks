import 'package:flutter/material.dart';

import '../data/task_dao.dart';
import '../data/task_importance.dart';
import '../theme.dart';
import 'flame_logo.dart';

/// Card representing a single recurring task and its live streak.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onDelete,
    this.onEditImportance,
  });

  final TaskWithStreaks entry;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  /// Opens the importance editor. When null the importance chip is inert.
  final VoidCallback? onEditImportance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;
    final streak = entry.currentStreak;
    final doneToday = entry.completedToday;

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
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
                        ),
                        const SizedBox(width: 8),
                        _ImportanceChip(
                          importance: task.importance,
                          onTap: onEditImportance,
                        ),
                      ],
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
                        FlameLogo(
                          size: 16,
                          color: streak > 0
                              ? StreaksTheme.flameOrange
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          streak == 1 ? '1 día' : '$streak días',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: streak > 0
                                ? StreaksTheme.flameOrange
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.reminderHour != null) ...[
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

/// Small badge showing the importance level of a task.
///
/// Tapping it opens the importance editor, when one is provided.
class _ImportanceChip extends StatelessWidget {
  const _ImportanceChip({required this.importance, this.onTap});

  final TaskImportance importance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = importance.isEscalating
        ? StreaksTheme.flameRed
        : StreaksTheme.flameOrange;

    return Tooltip(
      message: importance.description,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                importance.isEscalating
                    ? Icons.priority_high_rounded
                    : Icons.circle_outlined,
                size: 12,
                color: accent,
              ),
              const SizedBox(width: 4),
              Text(
                importance.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final alive = doneToday || streak > 0;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: alive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  StreaksTheme.flameYellow,
                  StreaksTheme.flameOrange,
                  StreaksTheme.flameRed,
                ],
              )
            : null,
        color: alive ? null : scheme.surfaceContainerHighest,
        border: Border.all(
          color: alive ? Colors.transparent : scheme.outline,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$streak',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: alive ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
