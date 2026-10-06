#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="$HOME/terhux/repo"; COMMAND_DIR="$REPO_DIR/commands"; RESULT_DIR="$REPO_DIR/results"
mkdir -p "$COMMAND_DIR" "$RESULT_DIR"
command_file="${1:-}"; [ -n "$command_file" ] || command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
[ -n "$command_file" ] && [ -f "$command_file" ] || exit 0
id=$(basename "$command_file" .cmd); raw=$(cat "$command_file")
action=$(printf '%s\n' "$raw"|sed -n 's/^ACTION=//p'|head -n1); project=$(printf '%s\n' "$raw"|sed -n 's/^PROJECT=//p'|head -n1); rel_path=$(printf '%s\n' "$raw"|sed -n 's/^PATH=//p'|head -n1); approved=$(printf '%s\n' "$raw"|sed -n 's/^APPROVED=//p'|head -n1)
status=SUCCESS; exit_code=0; stdout=""; stderr=""
[ "$approved" = true ] || { status=BLOCKED; stderr="APPROVED=true is required."; }
[ -n "$action" ] || { status=BLOCKED; stderr="ACTION is required."; }
if [ "$status" = SUCCESS ]; then
case "$action" in
terhux-runner-version) stdout="TERHUX_RUNNER_BUILD=2026-10-06-diagnostics-v3" ;;
netboost-cap-debug|netboost-cap-sync)
  cd "$HOME/netboost" 2>/dev/null || { status=ERROR; exit_code=1; stderr="NetBoost directory is missing."; }
  if [ "$status" = SUCCESS ]; then
    log=/tmp/netboost-cap-debug.log; rm -f "$log"
    echo "=== npm run build ===" >"$log"; npm run build >>"$log" 2>&1; b=$?
    if [ "$b" -ne 0 ]; then exit_code=$b; status=ERROR
    else echo "=== npx cap sync ===" >>"$log"; npx cap sync >>"$log" 2>&1; exit_code=$?; [ "$exit_code" -ne 0 ] && status=ERROR; fi
    stdout=$(cat "$log")
  fi ;;
netboost-cap-debug-log) [ -f /tmp/netboost-cap-debug.log ] && stdout=$(cat /tmp/netboost-cap-debug.log) || { status=ERROR; exit_code=1; stderr="Debug log missing."; } ;;
netboost-build)\n  log=/tmp/netboost-build.log; rm -f "$log";\n  { echo "=== NetBoost build diagnostics ==="; echo "PWD=$HOME/netboost"; echo "DATE=$(date -Iseconds)"; echo "NODE=$(node --version 2>&1 || true)"; echo "NPM=$(npm --version 2>&1 || true)"; echo "NPM_PATH=$(command -v npm 2>&1 || true)"; echo "DIR_EXISTS=$( [ -d "$HOME/netboost" ] && echo yes || echo no )"; echo "PACKAGE_EXISTS=$( [ -f "$HOME/netboost/package.json" ] && echo yes || echo no )"; echo "DISK="; df -h "$HOME/netboost" 2>&1 || true; echo "=== npm run build ==="; cd "$HOME/netboost" && npm run build; } >"$log" 2>&1; exit_code=$?; stdout=$(cat "$log" 2>/dev/null || true); [ "$exit_code" -ne 0 ] && status=ERROR ;;
netboost-android-build) if [ -x "$HOME/netboost/android/gradlew" ]; then state="$HOME/netboost/.terhux-android-build"; mkdir -p "$state"; if [ -f "$state/pid" ] && kill -0 "$(cat "$state/pid" 2>/dev/null)" 2>/dev/null; then status=ERROR; exit_code=1; stderr="Android build already running."; else rm -f "$state/pid"; nohup bash "$REPO_DIR/scripts/netboost-android-build-job.sh" >/dev/null 2>&1 & pid=$!; echo "$pid" >"$state/pid"; stdout="STARTED PID=$pid"; fi; else status=ERROR; exit_code=1; stderr="Android project or Gradle wrapper is missing."; fi ;;
netboost-android-build-status) state="$HOME/netboost/.terhux-android-build"; stdout=$(printf 'STATUS='; cat "$state/status" 2>/dev/null||echo NOT_STARTED; printf '\nPID='; cat "$state/pid" 2>/dev/null||echo none; printf '\nAPK_FILES\n'; find "$HOME/netboost/android/app/build/outputs/apk" -type f 2>/dev/null|sort) ;;
netboost-android-build-log) [ -f "$HOME/netboost/.terhux-android-build/build.log" ] && stdout=$(tail -250 "$HOME/netboost/.terhux-android-build/build.log") || { status=ERROR; exit_code=1; stderr="Android build log missing."; } ;;
netboost-deps-status) cd "$HOME/netboost" && stdout=$(printf 'VITE='; [ -x node_modules/.bin/vite ]&&echo yes||echo no; printf 'CAPACITOR='; [ -x node_modules/.bin/capacitor ]&&echo yes||echo no; printf 'ANDROID='; [ -d android ]&&echo yes||echo no; printf 'DIST='; [ -d dist ]&&echo yes||echo no) ;;
netboost-install-android) cd "$HOME/netboost" && npm install @capacitor/android@^8.0.0; exit_code=$?; [ "$exit_code" -ne 0 ]&&status=ERROR ;;
netboost-cap-add) cd "$HOME/netboost" && npm install @capacitor/android@^8.0.0 && npx cap add android; exit_code=$?; [ "$exit_code" -ne 0 ]&&status=ERROR ;;
*) status=BLOCKED; exit_code=1; stderr="Action is not on the Terhux safety allowlist." ;;
esac
fi
[ "$exit_code" -eq 0 ] || status=ERROR
{ echo TERHUX_RESULT_V1; echo "ID=$id"; echo "ACTION=$action"; echo "PROJECT=$project"; echo "PATH=$rel_path"; echo "APPROVED=$approved"; echo "STATUS=$status"; echo "EXIT_CODE=$exit_code"; echo "TIME=$(date +%s)"; echo STDOUT_BEGIN; printf '%s\n' "$stdout"; echo STDOUT_END; echo STDERR_BEGIN; printf '%s\n' "$stderr"; echo STDERR_END; } >"$RESULT_DIR/$id.result"
rm -f "$command_file"
git -C "$REPO_DIR" add commands results >/dev/null 2>&1||true
git -C "$REPO_DIR" commit -m "Terhux result: $id" >/dev/null 2>&1||true
for attempt in 1 2 3 4 5; do
  if git -C "$REPO_DIR" fetch origin main >/dev/null 2>&1 && git -C "$REPO_DIR" rebase origin/main >/dev/null 2>&1 && git -C "$REPO_DIR" push origin HEAD:main >/dev/null 2>&1; then break; fi
  git -C "$REPO_DIR" rebase --abort >/dev/null 2>&1 || true
  sleep 2
done
