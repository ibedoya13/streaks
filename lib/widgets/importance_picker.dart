import 'package:flutter/material.dart';

import '../data/task_importance.dart';
import 'importance_selector.dart';

/// Opens the importance picker and returns the chosen level, or null when
/// the user leaves without picking one.
///
/// It is shared by the home screen and the detail view, so the level of a
/// task can be changed from both without duplicating the sheet.
Future<TaskImportance?> showImportancePicker(
  BuildContext context, {
  required TaskImportance current,
  String? subtitle,
}) {
  return showModalBottomSheet<TaskImportance>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (sheetContext) {
      var value = current;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            // Scrollable for the same reason as the new-task sheet: with a
            // tall keyboard the available height can be too small.
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ImportanceSelector(
                    value: value,
                    onChanged: (selected) {
                      setSheetState(() => value = selected);
                      Navigator.of(sheetContext).pop(selected);
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
}
