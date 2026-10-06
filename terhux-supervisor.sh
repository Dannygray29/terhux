#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

# Keep the bridge alive. If the watcher ever exits, restart it automatically.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >/dev/null 2>&1 || true
fi

while true; do
  chmod +x "$REPO_DIR/terhux-runner.sh" "$REPO_DIR/terhux-watch.sh" 2>/dev/null || true
  "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/bridge.log" 2>&1 || true
  sleep 2
done
