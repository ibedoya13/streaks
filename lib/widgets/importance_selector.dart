import 'package:flutter/material.dart';

import '../data/task_importance.dart';
import '../theme.dart';

/// Lets the user pick how important a task is.
///
/// The two levels are shown as cards rather than a dropdown so the
/// difference between them is obvious at a glance.
class ImportanceSelector extends StatelessWidget {
  const ImportanceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TaskImportance value;
  final ValueChanged<TaskImportance> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final level in TaskImportance.values) ...[
          _ImportanceOption(
            level: level,
            selected: level == value,
            onTap: () => onChanged(level),
          ),
          if (level != TaskImportance.values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ImportanceOption extends StatelessWidget {
  const _ImportanceOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final TaskImportance level;
  final bool selected;
  final VoidCallback onTap;

  /// The accent colour that represents this level.
  Color get _accent => switch (level) {
    TaskImportance.normal => StreaksTheme.flameOrange,
    TaskImportance.critical => StreaksTheme.flameRed,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? _accent.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _accent : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                level.isEscalating
                    ? Icons.priority_high_rounded
                    : Icons.check_circle_outline,
                size: 22,
                color: selected ? _accent : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? _accent : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 20, color: _accent),
            ],
          ),
        ),
      ),
    );
  }
}
