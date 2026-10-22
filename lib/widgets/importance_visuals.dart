import 'package:flutter/material.dart';

import '../data/task_importance.dart';
import '../theme.dart';

/// How each level of importance is presented in the UI.
///
/// Keeping the colour and the icon together means the task card and the
/// importance selector can never drift apart.
extension TaskImportanceVisuals on TaskImportance {
  /// The accent colour that represents this level.
  Color get accent => switch (this) {
    TaskImportance.normal => StreaksTheme.flameOrange,
    TaskImportance.important => StreaksTheme.flameYellow,
    TaskImportance.critical => StreaksTheme.flameRed,
  };

  /// The icon that represents this level.
  IconData get icon => switch (this) {
    TaskImportance.normal => Icons.check_circle_outline,
    TaskImportance.important => Icons.priority_high,
    TaskImportance.critical => Icons.warning_amber_rounded,
  };

  /// How often the reminders of this level repeat, in words.
  String get intervalLabel {
    final interval = reminderInterval;
    if (interval == null) return 'Un solo aviso';
    final minutes = interval.inMinutes;
    return minutes == 1 ? 'Cada minuto' : 'Cada $minutes minutos';
  }
}
