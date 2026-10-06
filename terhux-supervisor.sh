#!/data/data/com.termux/files/usr/bin/bash

# Self-healing Terhux supervisor.
REPO_DIR="$HOME/terhux/repo"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

while true; do
    if ! pgrep -f "$REPO_DIR/terhux-watch.sh" >/dev/null 2>&1; then
        nohup "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/watch.log" 2>&1 &
    fi
    sleep 30
done
