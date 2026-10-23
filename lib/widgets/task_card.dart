import 'package:flutter/material.dart';

import '../data/task_dao.dart';
import '../theme.dart';

/// Card representing a single recurring task and its live streak.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onOpenDetail,
    this.dueLabel,
  });

  final TaskWithStreaks entry;

  /// Swiping the card to the right marks the task as completed.
  final VoidCallback onToggle;

  /// Swiping the card to the left opens the detail view.
  final VoidCallback onOpenDetail;

  /// When the task comes due, shown on the tasks of the coming days.
  final String? dueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = entry.task;
    final streak = entry.currentStreak;
    final doneToday = entry.isCycleDone;

    // The card is never dismissed for good: both swipe actions are handled
    // in `confirmDismiss` and the card springs back to its place.
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle();
        } else {
          onOpenDetail();
        }
        return false;
      },
      background: const _SwipeBackground(
        color: StreaksTheme.flameOrange,
        icon: Icons.check_circle_outline,
        label: 'Completar',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _SwipeBackground(
        color: StreaksTheme.inkMuted,
        icon: Icons.info_outline,
        label: 'Detalle',
        alignment: Alignment.centerRight,
      ),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpenDetail,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _StreakBadge(streak: streak, doneToday: doneToday),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The title takes the full width on its own line.
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
                      const SizedBox(height: 6),
                      // The card carries the streak, the name and the hour of
                      // the reminder. Everything else lives in the detail
                      // view, reached with a swipe to the left.
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(task.reminderHour, task.reminderMinute),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          if (dueLabel != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: StreaksTheme.flameOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueLabel!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: StreaksTheme.flameOrange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

/// Panel revealed behind the card while it is being swiped.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Icon(icon, color: Colors.white, size: 26),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
