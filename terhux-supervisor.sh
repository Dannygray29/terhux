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

# A crashed watcher is restarted with bounded exponential backoff. This avoids
# tight restart loops when Termux storage or the runtime environment is broken.
RESTART_DELAY=2
MAX_RESTART_DELAY=60

while true; do
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "repository unavailable: $REPO_DIR"
    sleep 5
    continue
  fi
  # Never chmod tracked repository files at runtime: mode changes can dirty
  # the worktree and prevent safe synchronization. Activation/installation is
  # responsible for executable permissions.
  if [ ! -r "$REPO_DIR/terhux-watch.sh" ]; then
    log "watcher script is missing or unreadable; retrying in ${RESTART_DELAY}s"
    sleep "$RESTART_DELAY"
    [ "$RESTART_DELAY" -lt "$MAX_RESTART_DELAY" ] && RESTART_DELAY=$((RESTART_DELAY * 2))
    [ "$RESTART_DELAY" -le "$MAX_RESTART_DELAY" ] || RESTART_DELAY="$MAX_RESTART_DELAY"
    continue
  fi
  bash "$REPO_DIR/terhux-watch.sh" >>"$LOG_DIR/bridge.log" 2>&1
  rc=$?
  log "watcher exited with code $rc; restarting in ${RESTART_DELAY}s"
  sleep "$RESTART_DELAY"
  if [ "$rc" -eq 0 ]; then
    RESTART_DELAY=2
  else
    [ "$RESTART_DELAY" -lt "$MAX_RESTART_DELAY" ] && RESTART_DELAY=$((RESTART_DELAY * 2))
    [ "$RESTART_DELAY" -le "$MAX_RESTART_DELAY" ] || RESTART_DELAY="$MAX_RESTART_DELAY"
  fi
done
