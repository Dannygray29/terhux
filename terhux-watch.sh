#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
COMMAND_DIR="$REPO_DIR/commands"
LOG_DIR="$REPO_DIR/logs"
INTERVAL="${TERHUX_INTERVAL:-5}"

mkdir -p "$COMMAND_DIR" "$REPO_DIR/results" "$LOG_DIR"
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_DIR/bridge.log"; }

while true; do
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "repository unavailable: $REPO_DIR"
    sleep "$INTERVAL"
    continue
  fi

  # Intake must never depend on a successful git sync. GitHub Issues are
  # polled directly by the worker; the worker syncs results after execution.
  python3 "$REPO_DIR/terhux-issue-worker.py" >>"$LOG_DIR/bridge.log" 2>&1 || log "issue poll/worker returned non-zero"

  # Sync queued commands/results whenever possible. Failure is retried next loop.
  bash "$REPO_DIR/terhux-sync.sh" >>"$LOG_DIR/bridge.log" 2>&1 || log "sync returned non-zero; retrying"

  sleep "$INTERVAL"
done
