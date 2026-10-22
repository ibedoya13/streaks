import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/task_importance.dart';

/// A notification that has been scheduled with the operating system.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.taskId,
    required this.scheduledAt,
    required this.importance,
  });

  /// The id handed to the notification plugin.
  final int id;

  /// The task this reminder belongs to.
  final int taskId;

  /// When the notification will fire.
  final tz.TZDateTime scheduledAt;

  /// The importance level of the task, which decides how insistent it is.
  final TaskImportance importance;
}

/// Schedules the reminders for the user's tasks.
///
/// Normal tasks get a single reminder at their scheduled time. Critical tasks
/// repeat every [criticalInterval] until the user marks them as done, which
/// is achieved by scheduling a series of individual notifications and
/// cancelling the ones that have not fired yet.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// How often a critical task repeats its reminder.
  static const Duration criticalInterval = Duration(minutes: 15);

  /// How far ahead a critical task's repetitions are scheduled. The whole
  /// series is re-scheduled whenever the app comes to the foreground, so
  /// this only needs to cover the time until the next app open.
  static const int criticalRepeatCount = 8;

  /// Base for the notification ids. Every reminder of a task uses
  /// `taskId * idStride + slot`, which makes it possible to cancel all the
  /// reminders of a task with a simple range.
  static const int idStride = 100;

  bool _initialized = false;
  bool _permissionGranted = false;

  /// Whether the user granted the permission to post notifications.
  bool get hasPermission => _permissionGranted;

  /// Prepares the plugin, the timezone database and the notification channels.
  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      // Fall back to UTC if the platform timezone cannot be read.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _createChannels();
    _initialized = true;
  }

  /// Asks the user for the permission to post notifications.
  ///
  /// On Android 13+ this is a runtime permission. Returns true when the
  /// notifications will be shown.
  Future<bool> requestPermission() async {
    await initialize();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      // Not Android, assume the platform allows it.
      _permissionGranted = true;
      return true;
    }

    final granted = await android.requestNotificationsPermission();
    _permissionGranted = granted ?? false;
    return _permissionGranted;
  }

  /// Creates the notification channels the app uses.
  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'streaks_normal',
        'Recordatorios',
        description: 'Avisos de tus tareas regulares',
        importance: Importance.defaultImportance,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'streaks_critical',
        'Recordatorios críticos',
        description: 'Avisos repetidos de tus tareas críticas',
        importance: Importance.max,
      ),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final taskId = int.tryParse(response.payload ?? '');
    if (taskId != null) {
      lastOpenedTaskId = taskId;
    }
  }

  /// The task whose notification was tapped, if any.
  int? lastOpenedTaskId;

  /// Schedules the reminders for a task.
  ///
  /// A normal task gets a single reminder. A critical task gets one at its
  /// scheduled time plus [criticalRepeatCount] repetitions, [criticalInterval]
  /// apart, so the user is nudged until the task is marked as done.
  Future<void> scheduleTask({
    required int taskId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required TaskImportance importance,
    DateTime? from,
  }) async {
    await initialize();
    if (!_permissionGranted) return;

    await cancelTask(taskId);

    final now = from ?? DateTime.now();
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time already passed today, start from the next day.
    if (!first.isAfter(tz.TZDateTime.now(tz.local))) {
      first = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    final repeats = importance.isEscalating ? criticalRepeatCount : 1;

    for (var slot = 0; slot < repeats; slot++) {
      final when = first.add(criticalInterval * slot);
      await _scheduleOne(
        id: taskId * idStride + slot,
        taskId: taskId,
        title: title,
        body: body,
        when: when,
        importance: importance,
      );
    }
  }

  Future<void> _scheduleOne({
    required int id,
    required int taskId,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required TaskImportance importance,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        importance.isEscalating ? 'streaks_critical' : 'streaks_normal',
        importance.isEscalating
            ? 'Recordatorios críticos'
            : 'Recordatorios',
        channelDescription: importance.isEscalating
            ? 'Avisos repetidos de tus tareas críticas'
            : 'Avisos de tus tareas regulares',
        importance: importance.isEscalating
            ? Importance.max
            : Importance.defaultImportance,
        priority: importance.isEscalating ? Priority.max : Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        autoCancel: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$taskId',
    );
  }

  /// Cancels every reminder scheduled for a task.
  Future<void> cancelTask(int taskId) async {
    await initialize();

    for (var slot = 0; slot < criticalRepeatCount; slot++) {
      await _plugin.cancel(id: taskId * idStride + slot);
    }
  }

  /// Cancels every reminder the app has scheduled.
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  /// The reminders currently scheduled with the operating system.
  Future<List<PendingNotificationRequest>> pending() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  /// Shows a notification right away, used to verify the setup works.
  @visibleForTesting
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streaks_normal',
          'Recordatorios',
          channelDescription: 'Avisos de tus tareas regulares',
          importance: Importance.defaultImportance,
        ),
      ),
      payload: '$id',
    );
  }
}
