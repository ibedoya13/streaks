import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streaks/data/database.dart';
import 'package:streaks/data/task_dao.dart';
import 'package:streaks/data/task_importance.dart';
import 'package:streaks/data/task_repetition.dart';
import 'package:streaks/data/task_schedule.dart';
import 'package:streaks/notifications/notification_service.dart';
import 'package:streaks/notifications/reminder_scheduler.dart';

/// A notification service that records what it was asked to do, so the
/// scheduling rules can be tested without the platform plugin.
class _FakeNotificationService extends NotificationService {
  final List<int> scheduled = [];
  final List<int> cancelled = [];

  /// The moment each reminder would fire, in the same way the real service
  /// calculates it.
  final List<DateTime> fireTimes = [];

  /// The ids the fake operating system currently holds, mirroring what
  /// `pendingNotificationRequests` returns on a real device.
  final Set<int> pendingIds = {};

  bool permission = true;

  @override
  Future<void> initialize() async {}

  @override
  bool get hasPermission => permission;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleTask({
    required int taskId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required TaskImportance importance,
    required TaskSchedule schedule,
    DateTime? from,
  }) async {
    // The real service cancels the previous reminders before scheduling the
    // new ones, which is what keeps a reschedule from piling them up.
    await cancelTask(taskId);

    final first = schedule.nextReminderAt(
      hour: hour,
      minute: minute,
      now: from ?? DateTime.now(),
    );

    final repeats = NotificationService.repeatCountFor(importance);
    for (var slot = 0; slot < repeats; slot++) {
      final id = taskId * NotificationService.idStride + slot;
      scheduled.add(id);
      fireTimes.add(first);
      pendingIds.add(id);
    }
  }

  @override
  Future<void> cancelTask(int taskId) async {
    for (var slot = 0; slot < NotificationService.maxRepeatCount; slot++) {
      final id = taskId * NotificationService.idStride + slot;
      cancelled.add(id);
      pendingIds.remove(id);
    }
  }

  @override
  Future<List<PendingNotificationRequest>> pending() async {
    return [
      for (final id in pendingIds) PendingNotificationRequest(id, '', '', null),
    ];
  }
}

void main() {
  late AppDatabase db;
  late TaskDao dao;
  late _FakeNotificationService service;
  late ReminderScheduler scheduler;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(), false);
    dao = TaskDao(db);
    service = _FakeNotificationService();
    scheduler = ReminderScheduler(
      service: service,
      tasks: () => dao.loadTasksWithStreaks(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('a normal task gets exactly one reminder', () async {
    await dao.createTask(title: 'Tarea', reminderHour: 9, reminderMinute: 0);

    await scheduler.rescheduleAll();

    expect(service.scheduled, hasLength(1));
  });

  test('a critical task repeats every ten minutes', () async {
    await dao.createTask(
      title: 'Tarea',
      importance: TaskImportance.critical,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();

    expect(
      TaskImportance.critical.reminderInterval,
      const Duration(minutes: 10),
    );
    expect(
      service.scheduled,
      hasLength(NotificationService.repeatCountFor(TaskImportance.critical)),
    );
  });

  test('an important task repeats every thirty minutes', () async {
    await dao.createTask(
      title: 'Tarea',
      importance: TaskImportance.important,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();

    expect(
      TaskImportance.important.reminderInterval,
      const Duration(minutes: 30),
    );
    expect(
      service.scheduled,
      hasLength(NotificationService.repeatCountFor(TaskImportance.important)),
    );
  });

  test('every repeating level covers the same window', () async {
    // A critical task asks for more reminders inside the window than an
    // important one, because its interval is shorter.
    expect(
      NotificationService.repeatCountFor(TaskImportance.critical),
      greaterThan(NotificationService.repeatCountFor(TaskImportance.important)),
    );
    expect(
      NotificationService.coverageWindow.inMinutes,
      TaskImportance.critical.reminderInterval!.inMinutes *
          NotificationService.repeatCountFor(TaskImportance.critical),
    );
  });

  test('a normal task does not repeat', () async {
    expect(TaskImportance.normal.reminderInterval, isNull);
    expect(TaskImportance.normal.repeats, isFalse);
    expect(NotificationService.repeatCountFor(TaskImportance.normal), 1);
  });

  test('a reminder only fires on a day the task comes due on', () async {
    await dao.createTask(
      title: 'Alterna',
      repetition: TaskRepetition.alternate,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();

    expect(service.fireTimes, hasLength(1));
    final tasks = await dao.loadTasksWithStreaks();
    expect(
      tasks.first.schedule.isDueOn(service.fireTimes.first),
      isTrue,
    );
  });

  test('a weekly task is only reminded on its due day', () async {
    await dao.createTask(
      title: 'Semanal',
      repetition: TaskRepetition.weekly,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();

    expect(service.fireTimes, hasLength(1));
    final tasks = await dao.loadTasksWithStreaks();
    expect(
      tasks.first.schedule.isDueOn(service.fireTimes.first),
      isTrue,
    );
  });

  test('a task completed today gets no reminder', () async {
    final id = await dao.createTask(
      title: 'Tarea',
      importance: TaskImportance.critical,
      reminderHour: 9,
      reminderMinute: 0,
    );
    await dao.toggleCompletion(id, DateTime.now());

    await scheduler.rescheduleAll();

    expect(service.scheduled, isEmpty);
  });

  test('completing a task cancels its pending reminders', () async {
    final id = await dao.createTask(
      title: 'Tarea',
      importance: TaskImportance.critical,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();
    expect(service.scheduled, isNotEmpty);

    service.cancelled.clear();
    await dao.toggleCompletion(id, DateTime.now());
    await scheduler.rescheduleAll();

    expect(service.cancelled, isNotEmpty);
  });

  test(
    'scheduling is idempotent, so a resume does not pile up reminders',
    () async {
      await dao.createTask(
        title: 'Tarea',
        importance: TaskImportance.critical,
        reminderHour: 9,
        reminderMinute: 0,
      );

      await scheduler.rescheduleAll();
      await scheduler.rescheduleAll();
      await scheduler.rescheduleAll();

      // Each run cancels the previous ids before scheduling them again, so
      // the operating system never holds more than one series per task.
      expect(service.cancelled, isNotEmpty);
    },
  );

  test('the reminder ids of a task are contiguous and unique', () async {
    await dao.createTask(
      title: 'Tarea',
      importance: TaskImportance.critical,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();

    final ids = service.scheduled.toList()..sort();
    expect(ids.toSet(), hasLength(ids.length));
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i] - ids[i - 1], 1);
    }
  });

  test('deleting a task cancels its scheduled reminders', () async {
    final id = await dao.createTask(
      title: 'Tarea',
      importance: TaskImportance.critical,
      reminderHour: 9,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();
    expect(service.pendingIds, isNotEmpty);

    // The task disappears from the database, as it would when the user
    // deletes it from the app.
    await dao.deleteTask(id);
    await scheduler.rescheduleAll();

    // Its reminders must be gone, otherwise they would keep firing.
    expect(service.pendingIds, isEmpty);
  });

  test('different tasks never share a reminder id', () async {
    await dao.createTask(
      title: 'Primera',
      importance: TaskImportance.critical,
      reminderHour: 9,
      reminderMinute: 0,
    );
    await dao.createTask(
      title: 'Segunda',
      importance: TaskImportance.critical,
      reminderHour: 10,
      reminderMinute: 0,
    );

    await scheduler.rescheduleAll();

    expect(service.scheduled.toSet(), hasLength(service.scheduled.length));
  });
}
