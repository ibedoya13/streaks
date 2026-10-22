import 'package:flutter/widgets.dart';

/// Notifies when the app returns to the foreground.
///
/// The reminders have to be re-scheduled on every resume: a critical task
/// that was not completed keeps nagging, and one that was completed stops.
class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver({this.onResumed});

  /// Called when the app comes back to the foreground.
  final Future<void> Function()? onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed?.call();
    }
  }
}
