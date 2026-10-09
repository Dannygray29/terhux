#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
LOG_DIR="$STATE_DIR/logs"
INTERVAL="${TERHUX_INTERVAL:-5}"
case "$INTERVAL" in ''|*[!0-9]*) INTERVAL=5 ;; esac
[ "$INTERVAL" -gt 0 ] || INTERVAL=5
mkdir -p "$LOG_DIR"
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_DIR/bridge.log"; }

while true; do
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "repository unavailable: $REPO_DIR"
    sleep "$INTERVAL"
    continue
  fi

  # GitHub Issues are the only request/reply transport. No job data is committed.
  python3 "$REPO_DIR/terhux-issue-worker.py" >>"$LOG_DIR/bridge.log" 2>&1 || log "issue poll/worker returned non-zero"
  sleep "$INTERVAL"
done
