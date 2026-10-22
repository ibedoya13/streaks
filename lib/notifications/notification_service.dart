import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/task_importance.dart';

/// Schedules the reminders for the user's tasks.
///
/// Normal tasks get a single reminder at their scheduled time. The repeating
/// levels (important and critical) repeat at the interval defined by the
/// level until the user marks them as done, which is achieved by scheduling
/// a series of individual notifications and cancelling the ones that have
/// not fired yet.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// How long the reminders of a repeating task keep nagging.
  ///
  /// Every repeating level covers the same window, so a critical task
  /// simply asks for more reminders inside it than an important one.
  static const Duration coverageWindow = Duration(hours: 2);

  /// How many notifications a task of the given importance gets scheduled.
  ///
  /// A normal task gets a single one; a repeating level gets one per
  /// interval until the coverage window is filled.
  static int repeatCountFor(TaskImportance importance) {
    final interval = importance.reminderInterval;
    if (interval == null) return 1;
    return coverageWindow.inMinutes ~/ interval.inMinutes;
  }

  /// The largest number of notifications any single task can have
  /// scheduled, used to cancel them all.
  static int get maxRepeatCount {
    var max = 1;
    for (final level in TaskImportance.values) {
      final count = repeatCountFor(level);
      if (count > max) max = count;
    }
    return max;
  }

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

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
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
        'streaks_important',
        'Recordatorios importantes',
        description: 'Avisos repetidos de tus tareas importantes',
        importance: Importance.high,
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

    final repeats = repeatCountFor(importance);
    final interval = importance.reminderInterval ?? Duration.zero;

    for (var slot = 0; slot < repeats; slot++) {
      final when = first.add(interval * slot);
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
        _channelIdFor(importance),
        _channelNameFor(importance),
        channelDescription: _channelDescriptionFor(importance),
        importance: _androidImportanceFor(importance),
        priority: _androidPriorityFor(importance),
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

  /// The channel a level of importance posts to.
  ///
  /// Each level has its own channel so the user can tune how intrusive each
  /// one is from the Android settings.
  static String _channelIdFor(TaskImportance importance) =>
      switch (importance) {
        TaskImportance.normal => 'streaks_normal',
        TaskImportance.important => 'streaks_important',
        TaskImportance.critical => 'streaks_critical',
      };

  static String _channelNameFor(TaskImportance importance) =>
      switch (importance) {
        TaskImportance.normal => 'Recordatorios',
        TaskImportance.important => 'Recordatorios importantes',
        TaskImportance.critical => 'Recordatorios críticos',
      };

  static String _channelDescriptionFor(TaskImportance importance) =>
      switch (importance) {
        TaskImportance.normal => 'Avisos de tus tareas regulares',
        TaskImportance.important =>
          'Avisos repetidos de tus tareas importantes',
        TaskImportance.critical => 'Avisos repetidos de tus tareas críticas',
      };

  static Importance _androidImportanceFor(TaskImportance importance) =>
      switch (importance) {
        TaskImportance.normal => Importance.defaultImportance,
        TaskImportance.important => Importance.high,
        TaskImportance.critical => Importance.max,
      };

  static Priority _androidPriorityFor(TaskImportance importance) =>
      switch (importance) {
        TaskImportance.normal => Priority.defaultPriority,
        TaskImportance.important => Priority.high,
        TaskImportance.critical => Priority.max,
      };

  /// Cancels every reminder scheduled for a task.
  Future<void> cancelTask(int taskId) async {
    await initialize();

    for (var slot = 0; slot < maxRepeatCount; slot++) {
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
}
