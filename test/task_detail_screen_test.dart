import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/database.dart';
import 'package:streaks/data/task_dao.dart';
import 'package:streaks/data/task_importance.dart';
import 'package:streaks/data/task_repetition.dart';
import 'package:streaks/data/task_schedule.dart';
import 'package:streaks/screens/task_detail_screen.dart';
import 'package:streaks/theme.dart';

/// Builds an entry to show in the detail view.
TaskWithStreaks _entry({
  int id = 1,
  String title = 'Tomar agua',
  String description = '',
  int streak = 3,
  int total = 8,
}) {
  final anchor = DateTime(2026, 10, 1);
  return TaskWithStreaks(
    task: StreakTask(
      id: id,
      title: title,
      description: description,
      importance: TaskImportance.normal,
      repetition: TaskRepetition.daily,
      reminderHour: 9,
      reminderMinute: 0,
      createdAt: anchor,
      isArchived: false,
      sortOrder: 0,
    ),
    schedule: TaskSchedule(anchor: anchor, repetition: TaskRepetition.daily),
    currentStreak: streak,
    bestStreak: 5,
    totalCompletions: total,
    completedToday: false,
    completedCycles: const {0, 1, 2},
    isForToday: true,
    isCycleDone: false,
    nextDueDay: anchor,
  );
}

void main() {
  late StreamController<List<TaskWithStreaks>> controller;
  late List<int> deleted;
  late List<(int, TaskImportance)> importanceChanges;

  setUp(() {
    controller = StreamController<List<TaskWithStreaks>>();
    deleted = [];
    importanceChanges = [];
  });

  tearDown(() async {
    await controller.close();
  });

  /// Shows the detail view with the given entry already loaded.
  Future<void> openDetail(WidgetTester tester, {TaskWithStreaks? entry}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StreaksTheme.light(),
        home: TaskDetailScreen(
          tasks: controller.stream,
          taskId: entry?.task.id ?? 1,
          onDelete: (id) async => deleted.add(id),
          onImportanceChanged: (id, importance) async =>
              importanceChanges.add((id, importance)),
        ),
      ),
    );

    controller.add([entry ?? _entry()]);
    // Explicit pumps instead of pumpAndSettle: the progress indicator spins
    // forever, so waiting for the tree to settle can never finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the name, the description and the streak', (tester) async {
    await openDetail(tester, entry: _entry(description: 'Dos litros al día'));

    expect(find.text('Tomar agua'), findsOneWidget);
    expect(find.text('Dos litros al día'), findsOneWidget);
    expect(find.text('Racha actual'), findsOneWidget);
    expect(find.text('3 veces'), findsOneWidget);
    expect(find.text('Mejor racha'), findsOneWidget);
    expect(find.text('Completados'), findsOneWidget);
  });

  testWidgets('the description is hidden when the task has none', (
    tester,
  ) async {
    await openDetail(tester, entry: _entry(title: 'Caminar'));

    expect(find.text('Caminar'), findsOneWidget);
    expect(find.text('Racha actual'), findsOneWidget);
  });

  testWidgets('the schedule of the task is shown', (tester) async {
    await openDetail(tester);

    expect(find.text('Recordatorio'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Repetición'), findsOneWidget);
    expect(find.text('Diaria'), findsOneWidget);
  });

  testWidgets('the importance can be changed from the detail view', (
    tester,
  ) async {
    await openDetail(tester);

    await tester.tap(find.text('Normal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The picker is open.
    expect(find.text('Importancia'), findsOneWidget);

    await tester.tap(find.text('Crítico'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(importanceChanges, [(1, TaskImportance.critical)]);
  });

  testWidgets('deleting asks for a confirmation first', (tester) async {
    await openDetail(tester);

    await tester.tap(find.text('Eliminar tarea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The confirmation is on screen and nothing has been deleted yet.
    expect(find.text('¿Eliminar la tarea?'), findsOneWidget);
    expect(deleted, isEmpty);
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    await openDetail(tester);

    await tester.tap(find.text('Eliminar tarea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(deleted, isEmpty);
    expect(find.text('Tomar agua'), findsOneWidget);
  });

  testWidgets('confirming deletes the task', (tester) async {
    await openDetail(tester);

    await tester.tap(find.text('Eliminar tarea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(deleted, [1]);
  });
}
