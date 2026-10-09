#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
STATE_DIR="$TMP_DIR/state"
mkdir -p "$HOME_DIR/spin" "$REPO_DIR" "$STATE_DIR/commands"
cp "$ROOT_DIR/terhux-exec.sh" "$REPO_DIR/terhux-exec.sh"
cp "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/terhux-runner.sh"
command -v npm >/dev/null || { echo 'SKIP: npm is not installed'; exit 0; }
command -v timeout >/dev/null || { echo 'SKIP: timeout is not installed'; exit 0; }

cat > "$HOME_DIR/spin/package.json" <<'JSON'
{"name":"timeout-test","version":"1.0.0","scripts":{"build":"node -e 'process.title=\"terhux-timeout-marker\"; while (true) {}'"}}
JSON
printf 'cd "%s/spin" && npm run build\n' "$HOME_DIR" > "$TMP_DIR/shell-command"
COMMAND_B64=$(python3 - "$TMP_DIR/shell-command" <<'PY'
import base64, sys
print(base64.b64encode(open(sys.argv[1], "rb").read()).decode("ascii"))
PY
)
cat > "$STATE_DIR/commands/runaway-build.cmd" <<CMD
ID=runaway-build
ACTION=shell-command
COMMAND_B64=$COMMAND_B64
APPROVED=true
CMD
HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" TERHUX_STATE_DIR="$STATE_DIR" \
  TERHUX_ACTION_TIMEOUT_SECONDS=1 bash "$REPO_DIR/terhux-runner.sh" "$STATE_DIR/commands/runaway-build.cmd"
RESULT="$STATE_DIR/results/runaway-build.result"
[ -f "$RESULT" ] || { echo 'FAIL: runner did not publish a local result' >&2; exit 1; }
grep -q '^STATUS=TIMEOUT$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: runaway shell command was not marked TIMEOUT' >&2; exit 1; }
grep -q '^EXIT_CODE=124$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: expected timeout exit code 124' >&2; exit 1; }
sleep 0.2
if pgrep -af '[t]erhux-timeout-marker' >/dev/null; then echo 'FAIL: runaway child process survived the timeout' >&2; exit 1; fi
echo 'PASS: raw shell command and its runaway child stop at the deadline; result remains local.'
