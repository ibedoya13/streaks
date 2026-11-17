import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/database.dart';
import 'package:streaks/data/task_dao.dart';
import 'package:streaks/data/task_importance.dart';
import 'package:streaks/data/task_repetition.dart';
import 'package:streaks/data/task_schedule.dart';
import 'package:streaks/theme.dart';
import 'package:streaks/widgets/task_card.dart';

/// Builds an entry to render in the card.
TaskWithStreaks _entry({
  int id = 1,
  String title = 'Tomar agua',
  String description = '',
  int streak = 3,
  bool completedToday = false,
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
    totalCompletions: 8,
    completedToday: completedToday,
    completedCycles: const {0, 1, 2},
    isForToday: true,
    isCycleDone: completedToday,
    nextDueDay: anchor,
  );
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required TaskWithStreaks entry,
    VoidCallback? onToggle,
    VoidCallback? onOpenDetail,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StreaksTheme.light(),
        home: Scaffold(
          body: TaskCard(
            entry: entry,
            onToggle: onToggle,
            onOpenDetail: onOpenDetail ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the card has no complete and no delete button', (tester) async {
    await pumpCard(tester, entry: _entry());

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('swiping to the right completes the task', (tester) async {
    var toggled = 0;
    await pumpCard(tester, entry: _entry(), onToggle: () => toggled++);

    await tester.fling(find.byType(TaskCard), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();

    expect(toggled, 1);
  });

  testWidgets('a task that does not come due today cannot be completed', (
    tester,
  ) async {
    var toggled = 0;
    var opened = 0;
    await pumpCard(
      tester,
      entry: _entry(),
      onToggle: null,
      onOpenDetail: () => opened++,
    );

    // The card only listens to the swipe to the left.
    await tester.fling(find.byType(TaskCard), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();

    expect(toggled, 0);
    expect(opened, 0);
    expect(find.byType(TaskCard), findsOneWidget);
  });

  testWidgets('swiping to the left opens the detail view', (tester) async {
    var opened = 0;
    await pumpCard(tester, entry: _entry(), onOpenDetail: () => opened++);

    await tester.fling(find.byType(TaskCard), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('the card stays in the list after a swipe', (tester) async {
    await pumpCard(tester, entry: _entry());

    await tester.fling(find.byType(TaskCard), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsOneWidget);
  });

  testWidgets('tapping the card opens the detail view', (tester) async {
    var opened = 0;
    await pumpCard(tester, entry: _entry(), onOpenDetail: () => opened++);

    await tester.tap(find.text('Tomar agua'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('the due day is shown when the card carries a label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StreaksTheme.light(),
        home: Scaffold(
          body: TaskCard(
            entry: _entry(),
            dueLabel: 'Mañana',
            onToggle: () {},
            onOpenDetail: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mañana'), findsOneWidget);
    expect(find.byIcon(Icons.event_outlined), findsOneWidget);
  });

  testWidgets('the due day is hidden when there is no label', (tester) async {
    await pumpCard(tester, entry: _entry());

    expect(find.byIcon(Icons.event_outlined), findsNothing);
  });

  testWidgets('the card only shows the streak, the name and the hour', (
    tester,
  ) async {
    await pumpCard(
      tester,
      entry: _entry(description: 'Dos litros al día', streak: 4),
    );

    // What stays.
    expect(find.text('Tomar agua'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    // What goes.
    expect(find.text('Dos litros al día'), findsNothing);
    expect(find.text('Normal'), findsNothing);
    expect(find.text('4 días'), findsNothing);
    expect(find.text('Diaria'), findsNothing);
    expect(find.byIcon(Icons.today_outlined), findsNothing);
  });

  testWidgets('the description is not shown even when the task has one', (
    tester,
  ) async {
    await pumpCard(tester, entry: _entry(description: 'Dos litros al día'));

    expect(find.text('Dos litros al día'), findsNothing);
  });
}
