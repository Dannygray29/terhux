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

  # Sync saves local queue/results first, then fetches/rebases/pushes. Never
  # reset hard: a pending result must survive a temporary network outage.
  if ! bash "$REPO_DIR/terhux-sync.sh"; then
    sleep "$INTERVAL"
    continue
  fi

  command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)

  if [ -n "$command_file" ] && [ -f "$command_file" ]; then
    log "processing request $(basename "$command_file" .cmd)"
    bash "$REPO_DIR/terhux-runner.sh" "$command_file" >>"$LOG_DIR/bridge.log" 2>&1 || log "runner returned non-zero for $(basename "$command_file" .cmd)"
  fi

  sleep "$INTERVAL"
done
