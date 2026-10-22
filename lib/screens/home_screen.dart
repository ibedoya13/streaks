import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/task_dao.dart';
import '../data/task_importance.dart';
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
  const HomeScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TaskDao _dao = TaskDao(widget.database);
  late final Stream<List<TaskWithStreaks>> _tasks =
      _dao.watchTasksWithStreaks();

  Future<void> _addTask({
    required String title,
    required String description,
    required TaskImportance importance,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    await _dao.createTask(
      title: title,
      description: description,
      importance: importance,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
  }

  Future<void> _toggleTask(int taskId) async {
    await _dao.toggleCompletion(taskId, DateTime.now());
  }

  Future<void> _deleteTask(int taskId) async {
    await _dao.deleteTask(taskId);
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
            );
          },
        );
      },
    );

    if (selected != null && selected != entry.task.importance) {
      await _dao.updateImportance(entry.task.id, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            FlameLogo(size: 30),
            SizedBox(width: 10),
            Text('Streaks'),
          ],
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
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
