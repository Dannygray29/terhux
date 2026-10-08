#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="$HOME/terhux/repo"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
if command -v termux-wake-lock >/dev/null 2>&1; then termux-wake-lock >/dev/null 2>&1 || true; fi
start_direct() {
  if pgrep -f "[t]erhux-direct.py" >/dev/null 2>&1; then return; fi
  cd "$REPO_DIR" 2>/dev/null || return
  nohup python3 "$REPO_DIR/terhux-direct.py" >>"$LOG_DIR/direct.log" 2>&1 </dev/null &
}
while true; do
  mkdir -p "$REPO_DIR" "$LOG_DIR" "$REPO_DIR/commands/.running/.pids" "$REPO_DIR/results" 2>/dev/null || true
  cd "$REPO_DIR" 2>/dev/null || true
  chmod +x "$REPO_DIR/terhux-runner.sh" "$REPO_DIR/terhux-watch.sh" 2>/dev/null || true
  start_direct
  "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/bridge.log" 2>&1 || true
  sleep 2
done
