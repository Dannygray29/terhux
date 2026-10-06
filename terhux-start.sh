#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

# Start the self-healing supervisor exactly once.
if pgrep -f "$REPO_DIR/terhux-supervisor.sh" >/dev/null 2>&1; then
    exit 0
fi

nohup "$REPO_DIR/terhux-supervisor.sh" >>"$LOG_DIR/supervisor.log" 2>&1 &
