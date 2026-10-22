#!/usr/bin/env bash
# Checks that the reminders are actually registered with Android's
# AlarmManager, which is the only way to know a scheduled notification will
# really fire.
#
# Usage: bash tool/check_alarms.sh [package]
set -uo pipefail

export PATH="$PATH:/Users/ibedoya/Library/Android/sdk/platform-tools"
PACKAGE="${1:-com.amarrete.streaks}"

echo "==> Pending alarms for $PACKAGE"
# Dumpsys alarms lists the alarms the system holds for each package.
adb shell dumpsys alarm 2>/dev/null \
  | grep -A3 "$PACKAGE" \
  | head -40

echo
echo "==> Notification channels"
adb shell dumpsys notification 2>/dev/null \
  | grep -A6 "streaks" \
  | head -30

echo
echo "==> Notification permission"
adb shell dumpsys package "$PACKAGE" 2>/dev/null \
  | grep -i "POST_NOTIFICATIONS" \
  | head -5
