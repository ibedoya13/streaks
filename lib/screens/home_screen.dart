import 'package:flutter/material.dart';

import '../models/streak_task.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/task_card.dart';

/// First screen of the app: the list of recurring tasks and their streaks.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<StreakTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadSeedData();
  }

  void _loadSeedData() {
    final today = DateTime.now();
    _tasks.addAll([
      StreakTask(
        id: 'seed-water',
        title: 'Tomar 2 litros de agua',
        description: 'Rutina diaria de hidratación',
        reminderHour: 9,
        reminderMinute: 0,
        completions: {
          DateTime(today.year, today.month, today.day - 3): true,
          DateTime(today.year, today.month, today.day - 2): true,
          DateTime(today.year, today.month, today.day - 1): true,
        },
      ),
      StreakTask(
        id: 'seed-walk',
        title: 'Caminar 30 minutos',
        description: 'Salir a caminar o correr',
        reminderHour: 18,
        reminderMinute: 30,
        completions: {
          DateTime(today.year, today.month, today.day - 1): true,
        },
      ),
    ]);
  }

  void _addTask(StreakTask task) {
    setState(() => _tasks.add(task));
  }

  void _toggleTask(StreakTask task) {
    setState(() => task.toggle(DateTime.now()));
  }

  void _deleteTask(StreakTask task) {
    setState(() => _tasks.remove(task));
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => AddTaskSheet(onSubmit: _addTask),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneCount = _tasks
        .where((t) => t.isCompletedOn(DateTime.now()))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaks'),
        actions: [
          if (_tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$doneCount/${_tasks.length} hoy',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
      body: _tasks.isEmpty
          ? _EmptyState(onAdd: _openAddSheet)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: _tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return TaskCard(
                  task: task,
                  onToggle: () => _toggleTask(task),
                  onDelete: () => _deleteTask(task),
                );
              },
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
            Icon(
              Icons.local_fire_department_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
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
