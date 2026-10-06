#!/data/data/com.termux/files/usr/bin/bash
REPO_DIR="$HOME/terhux/repo"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
while true; do
  [ -d "$REPO_DIR" ] || { sleep 10; continue; }
  chmod +x "$REPO_DIR"/terhux-*.sh "$REPO_DIR"/boot/start-terhux 2>/dev/null || true
  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true
  if ! pgrep -f "$REPO_DIR/terhux-watch.sh" >/dev/null 2>&1; then
    nohup "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/watch.log" 2>&1 &
    echo "$(date '+%Y-%m-%d %H:%M:%S') watcher started" >>"$LOG_DIR/supervisor.log"
  fi
  sleep 15
done
