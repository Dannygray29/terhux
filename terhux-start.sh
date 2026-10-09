#!/data/data/com.termux/files/usr/bin/bash
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR"
if pgrep -f "$REPO_DIR/terhux-supervisor.sh" >/dev/null 2>&1; then
  echo "Terhux supervisor is already running."
  exit 0
fi
nohup "$REPO_DIR/terhux-supervisor.sh" >>"$LOG_DIR/supervisor.log" 2>&1 &
echo "Started Terhux issue bridge."
