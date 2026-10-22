import 'package:flutter/material.dart';

import '../models/streak_task.dart';

/// Bottom sheet used to create a new recurring task.
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key, required this.onSubmit});

  final ValueChanged<StreakTask> onSubmit;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      StreakTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        reminderHour: _reminderEnabled ? _reminderTime.hour : null,
        reminderMinute: _reminderEnabled ? _reminderTime.minute : null,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Nueva tarea',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tarea',
                hintText: 'Ej. Tomar 2 litros de agua',
                prefixIcon: Icon(Icons.task_alt),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Escribe un nombre para la tarea'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Recordatorio diario'),
              subtitle: const Text('Recibirás un aviso aunque no abras la app'),
            ),
            if (_reminderEnabled)
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime,
                  );
                  if (picked != null) setState(() => _reminderTime = picked);
                },
                icon: const Icon(Icons.schedule),
                label: Text('Hora del aviso: ${_reminderTime.format(context)}'),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add),
              label: const Text('Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
