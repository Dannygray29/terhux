#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/netboost"
STATE="$ROOT/.terhux-android-build"
LOG="$STATE/build.log"
PIDFILE="$STATE/pid"
STATUSFILE="$STATE/status"
mkdir -p "$STATE"

echo "STARTED $(date +%s)" > "$STATUSFILE"
rm -f "$PIDFILE"
cd "$ROOT/android" || { echo "ERROR 1 Android project missing" > "$STATUSFILE"; exit 1; }

./gradlew assembleDebug > "$LOG" 2>&1
code=$?

if [ "$code" -eq 0 ]; then
  echo "SUCCESS 0 $(date +%s)" > "$STATUSFILE"
else
  echo "ERROR $code $(date +%s)" > "$STATUSFILE"
fi
rm -f "$PIDFILE"
exit "$code"
