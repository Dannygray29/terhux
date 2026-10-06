#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

chmod +x "$REPO_DIR/terhux-runner.sh" "$REPO_DIR/terhux-watch.sh" 2>/dev/null || true

if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >/dev/null 2>&1 || true
fi

if ! pgrep -f "$REPO_DIR/terhux-watch.sh" >/dev/null 2>&1; then
  nohup "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/bridge.log" 2>&1 &
fi
