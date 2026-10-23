#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
LOG_DIR="$STATE_DIR/logs"
INTERVAL="${TERHUX_INTERVAL:-5}"
MAX_BACKOFF="${TERHUX_MAX_BACKOFF:-60}"
case "$INTERVAL" in ''|*[!0-9]*) INTERVAL=5 ;; esac
case "$MAX_BACKOFF" in ''|*[!0-9]*) MAX_BACKOFF=60 ;; esac
[ "$INTERVAL" -gt 0 ] || INTERVAL=5
[ "$MAX_BACKOFF" -ge "$INTERVAL" ] || MAX_BACKOFF=60
mkdir -p "$LOG_DIR"
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_DIR/bridge.log"; }

# Back off after errors so a revoked GitHub session does not hammer the API.
# A successful poll resets the delay to the configured normal interval.
delay="$INTERVAL"
while true; do
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "repository unavailable: $REPO_DIR"
    sleep "$delay"
    [ "$delay" -lt "$MAX_BACKOFF" ] && delay=$((delay * 2))
    [ "$delay" -le "$MAX_BACKOFF" ] || delay="$MAX_BACKOFF"
    continue
  fi

  if ! command -v gh >/dev/null 2>&1; then
    log "GitHub CLI missing; install with: pkg install gh"
    sleep "$delay"
    [ "$delay" -lt "$MAX_BACKOFF" ] && delay=$((delay * 2))
    [ "$delay" -le "$MAX_BACKOFF" ] || delay="$MAX_BACKOFF"
    continue
  fi

  if ! gh auth status -h github.com >/dev/null 2>&1; then
    log "GitHub authentication unavailable; run gh auth login in Termux"
    sleep "$delay"
    [ "$delay" -lt "$MAX_BACKOFF" ] && delay=$((delay * 2))
    [ "$delay" -le "$MAX_BACKOFF" ] || delay="$MAX_BACKOFF"
    continue
  fi

  # One worker at a time; never launch overlapping pollers from this watcher.
  python3 "$REPO_DIR/terhux-issue-worker.py" >>"$LOG_DIR/bridge.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    delay="$INTERVAL"
    sleep "$INTERVAL"
  else
    log "issue poll/worker returned non-zero (exit $rc); retry delay ${delay}s"
    sleep "$delay"
    [ "$delay" -lt "$MAX_BACKOFF" ] && delay=$((delay * 2))
    [ "$delay" -le "$MAX_BACKOFF" ] || delay="$MAX_BACKOFF"
  fi
done
