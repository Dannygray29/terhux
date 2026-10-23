#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUPERVISOR="$ROOT/terhux-supervisor.sh"
tmp="$(mktemp -d)"
supervisor_pid=""
cleanup() {
  if [ -n "$supervisor_pid" ]; then
    kill "$supervisor_pid" 2>/dev/null || true
    wait "$supervisor_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM
mkdir -p "$tmp/repo/.git" "$tmp/bin" "$tmp/state"
cp "$SUPERVISOR" "$tmp/repo/terhux-supervisor.sh"
# Use the supervisor's documented path overrides rather than brittle source
# substitutions. The isolated fake watcher only writes under the temp state.
cat > "$tmp/repo/terhux-watch.sh" <<'WATCH'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$WATCHER_OUTCOME" >> "$TERHUX_STATE_DIR/watcher-runs"
if [ "$WATCHER_OUTCOME" = fail ]; then exit 17; fi
sleep 0.2
exit 0
WATCH
python - "$tmp/repo/terhux-supervisor.sh" <<'PY2'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
if 'MAX_RESTART_DELAY=60' not in s or 'sleep "$RESTART_DELAY"' not in s:
    raise SystemExit("BLOCKER: supervisor recovery structure changed; refusing blind test rewrite.")
s = s.replace('MAX_RESTART_DELAY=60', 'MAX_RESTART_DELAY=4')
s = s.replace('sleep "$RESTART_DELAY"', 'sleep 0.1')
s = s.replace('sleep 5', 'sleep 0.1')
p.write_text(s)
PY2
cat > "$tmp/bin/termux-wake-lock" <<'CMD'
#!/usr/bin/env bash
exit 0
CMD
chmod +x "$tmp/bin/termux-wake-lock"
export PATH="$tmp/bin:$PATH"
export TERHUX_REPO_DIR="$tmp/repo"
export TERHUX_STATE_DIR="$tmp/state"
export WATCHER_OUTCOME=fail
bash "$tmp/repo/terhux-supervisor.sh" &
supervisor_pid=$!
# Wait for the expected crash record, with a finite deadline.
found=0
for _ in $(seq 1 30); do
  if grep -q 'watcher exited with code 17' "$tmp/state/logs/supervisor.log" 2>/dev/null; then
    found=1
    break
  fi
  sleep 0.1
done
if [ "$found" -ne 1 ]; then
  echo 'FAIL: supervisor did not record the injected watcher crash'
  cat "$tmp/state/logs/supervisor.log" 2>/dev/null || true
  exit 1
fi
if [ ! -s "$tmp/state/watcher-runs" ]; then
  echo 'FAIL: isolated watcher did not run'
  exit 1
fi
if ! grep -q 'restarting in' "$tmp/state/logs/supervisor.log"; then
  echo 'FAIL: restart/backoff was not logged'
  exit 1
fi
kill "$supervisor_pid" 2>/dev/null || true
wait "$supervisor_pid" 2>/dev/null || true
supervisor_pid=""
echo 'PASS: isolated supervisor launches watcher, records crash, and enters bounded restart path'
