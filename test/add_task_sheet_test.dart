import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/task_importance.dart';
import 'package:streaks/data/task_repetition.dart';
import 'package:streaks/theme.dart';
import 'package:streaks/widgets/add_task_sheet.dart';

/// Height of the keyboard the tests simulate. The device used for
/// development has a taller keyboard than the default, which used to make
/// the new-task sheet overflow.
const _tallKeyboard = 620.0;

void main() {
  Future<void> openSheet(WidgetTester tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: _tallKeyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: StreaksTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: false,
                  builder: (_) => AddTaskSheet(
                    onSubmit: ({
                      required String title,
                      required String description,
                      required TaskImportance importance,
                      required TaskRepetition repetition,
                      required int reminderHour,
                      required int reminderMinute,
                    }) async {},
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('the new-task sheet does not overflow with a tall keyboard', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Nueva tarea'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet can be scrolled to reach the submit button', (
    tester,
  ) async {
    await openSheet(tester);

    // The button is below the fold with a tall keyboard.
    final button = find.widgetWithText(FilledButton, 'Crear tarea');
    expect(button, findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(button).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });

  testWidgets('the sheet does not overflow without a keyboard', (tester) async {
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: StreaksTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
                builder: (_) => AddTaskSheet(
                  onSubmit: ({
                    required String title,
                    required String description,
                    required TaskImportance importance,
                    required TaskRepetition repetition,
                    required int reminderHour,
                    required int reminderMinute,
                  }) async {},
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Crear tarea'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
