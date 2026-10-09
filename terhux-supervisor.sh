#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR"
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_DIR/supervisor.log"; }
trap 'log "supervisor stopping"; exit 0' INT TERM

while true; do
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "repository unavailable: $REPO_DIR"
    sleep 5
    continue
  fi
  chmod +x "$REPO_DIR/terhux-runner.sh" "$REPO_DIR/terhux-watch.sh" 2>/dev/null || true
  bash "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/bridge.log" 2>&1
  rc=$?
  log "watcher exited with code $rc; restarting in 2 seconds"
  sleep 2
done
