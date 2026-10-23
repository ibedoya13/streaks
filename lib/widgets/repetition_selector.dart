import 'package:flutter/material.dart';

import '../data/task_repetition.dart';

/// Lets the user pick how often a task comes due.
class RepetitionSelector extends StatelessWidget {
  const RepetitionSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TaskRepetition value;
  final ValueChanged<TaskRepetition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final repetition in TaskRepetition.values) ...[
          _RepetitionOption(
            repetition: repetition,
            selected: repetition == value,
            onTap: () => onChanged(repetition),
          ),
          if (repetition != TaskRepetition.values.last)
            const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RepetitionOption extends StatelessWidget {
  const _RepetitionOption({
    required this.repetition,
    required this.selected,
    required this.onTap,
  });

  final TaskRepetition repetition;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (repetition) {
    TaskRepetition.daily => Icons.today_outlined,
    TaskRepetition.alternate => Icons.sync_alt,
    TaskRepetition.weekly => Icons.event_repeat_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.primary;

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
                ? accent.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 22,
                color: selected ? accent : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repetition.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? accent : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      repetition.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
