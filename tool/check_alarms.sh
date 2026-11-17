#!/usr/bin/env bash
# Checks that the reminders of the app are really registered with Android's
# AlarmManager, which is the only way to know a scheduled notification will
# really fire.
#
# It works on any machine: the adb binary is looked up in the PATH, in the
# usual Android SDK locations and in the ADB and ANDROID_HOME variables, so
# nothing here is tied to a particular computer.
#
# Usage: bash tool/check_alarms.sh [package]
set -uo pipefail

DEFAULT_PACKAGE="com.amarrete.streaks"

usage() {
  cat <<EOF
Usage: bash tool/check_alarms.sh [options] [package]

Checks that the reminders of an Android app are registered with the
AlarmManager and prints when each one will fire.

Options:
  -p, --package <name>   Package to inspect (default: $DEFAULT_PACKAGE)
  -h, --help             Show this help

Environment:
  ADB                    Full path to the adb binary, for when it is not on PATH
  ANDROID_HOME           Root of the Android SDK (ANDROID_SDK_ROOT also works)
  ANDROID_SERIAL         Device to use, when several are connected
EOF
}

PACKAGE="$DEFAULT_PACKAGE"

while [ $# -gt 0 ]; do
  case "$1" in
    -p | --package)
      if [ $# -lt 2 ]; then
        echo "Missing value for $1" >&2
        exit 2
      fi
      PACKAGE="$2"
      shift 2
      ;;
    --package=*)
      PACKAGE="${1#*=}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      PACKAGE="$1"
      shift
      ;;
  esac
done

# Looks for the adb binary without assuming a particular machine.
find_adb() {
  if [ -n "${ADB:-}" ] && [ -x "$ADB" ]; then
    echo "$ADB"
    return 0
  fi
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi

  local roots=()
  [ -n "${ANDROID_HOME:-}" ] && roots+=("$ANDROID_HOME")
  [ -n "${ANDROID_SDK_ROOT:-}" ] && roots+=("$ANDROID_SDK_ROOT")
  roots+=(
    "$HOME/Library/Android/sdk"
    "$HOME/Android/Sdk"
    "$HOME/android-sdk"
    "/usr/local/lib/android/sdk"
    "/opt/android-sdk"
  )

  local root
  for root in "${roots[@]}"; do
    if [ -x "$root/platform-tools/adb" ]; then
      echo "$root/platform-tools/adb"
      return 0
    fi
  done
  return 1
}

# Prints a unix timestamp in a readable way, on both BSD and GNU date.
format_time() { # <unix seconds>
  if date -r "$1" '+%Y-%m-%d %H:%M:%S' >/dev/null 2>&1; then
    date -r "$1" '+%Y-%m-%d %H:%M:%S'
  else
    date -d "@$1" '+%Y-%m-%d %H:%M:%S'
  fi
}

ADB_BIN="$(find_adb)"
if [ -z "$ADB_BIN" ]; then
  echo "adb not found." >&2
  echo "Install the Android SDK platform-tools, add them to the PATH or set" >&2
  echo "ADB=/path/to/adb." >&2
  exit 1
fi

echo "==> Using $ADB_BIN"

# Picks the device to inspect.
SERIAL="${ANDROID_SERIAL:-}"
if [ -z "$SERIAL" ]; then
  DEVICE_LINES="$("$ADB_BIN" devices | awk 'NR > 1 && NF > 0 {print}')"
  SERIAL="$(printf '%s\n' "$DEVICE_LINES" | awk '$2 == "device" {print $1; exit}')"
  if [ -z "$SERIAL" ]; then
    echo "No device is ready." >&2
    printf '%s\n' "$DEVICE_LINES" >&2
    echo "Connect a device and accept the debugging prompt if it shows up." >&2
    exit 1
  fi
fi

echo "==> Device $SERIAL"
echo "==> Package $PACKAGE"

# Dumpsys alarms lists the alarms the system holds for each package. The
# timestamp of an alarm is in its origWhen field.
ALARM_TIMES="$("$ADB_BIN" -s "$SERIAL" shell dumpsys alarm 2>/dev/null |
  awk -v pkg="$PACKAGE" '
    index($0, pkg) && match($0, /origWhen [0-9]+/) {
      print substr($0, RSTART + 9, RLENGTH - 9)
    }
  ' | sort -n)"

echo
echo "==> Pending alarms"
COUNT="$(printf '%s\n' "$ALARM_TIMES" | grep -c . || true)"
if [ "$COUNT" -eq 0 ]; then
  echo "    none"
else
  PREVIOUS=0
  while read -r MILLIS; do
    [ -n "$MILLIS" ] || continue
    SECONDS_AGO=$((MILLIS / 1000))
    printf '    %s' "$(format_time "$SECONDS_AGO")"
    if [ "$PREVIOUS" -ne 0 ]; then
      printf '   (+%d min)' "$(((SECONDS_AGO - PREVIOUS) / 60))"
    fi
    printf '\n'
    PREVIOUS="$SECONDS_AGO"
  done <<<"$ALARM_TIMES"

  MIN_GAP="$(printf '%s\n' "$ALARM_TIMES" |
    awk 'NR > 1 { d = ($1 - p) / 60000; if (m == "" || d < m) m = d } { p = $1 } END { if (m != "") print int(m) }')"
  echo "    $COUNT alarm(s)"
  if [ -n "$MIN_GAP" ]; then
    echo "    shortest gap: $MIN_GAP min"
  fi
fi

echo
echo "==> Notification channels"
# Only the block of the app, so the channels of other apps do not show up.
"$ADB_BIN" -s "$SERIAL" shell dumpsys notification 2>/dev/null |
  awk -v pkg="$PACKAGE" '
    {
      mine = index($0, "AppSettings: " pkg) > 0
      if (printing && !mine && index($0, "AppSettings: ")) exit
      if (mine) printing = 1
      if (printing) print
    }
  ' | head -30

echo
echo "==> Notification permission"
"$ADB_BIN" -s "$SERIAL" shell dumpsys package "$PACKAGE" 2>/dev/null |
  grep -i "POST_NOTIFICATIONS" |
  head -5
