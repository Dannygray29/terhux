#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
LOG_DIR="$STATE_DIR/logs"
LOG_FILE="$LOG_DIR/update.log"
REMOTE="${TERHUX_REMOTE:-origin}"
BRANCH="${TERHUX_BRANCH:-main}"
mkdir -p "$LOG_DIR" 2>/dev/null || true
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
cd "$REPO_DIR" 2>/dev/null || { log "repository unavailable: $REPO_DIR"; exit 1; }

# Job state lives under ~/.local/state/terhux, never in this Git checkout.
# Refuse to overwrite tracked phone-side edits; never reset or use git pull.
if ! git diff --quiet || ! git diff --cached --quiet; then
  log "update skipped: tracked local edits exist; no files were changed"
  exit 1
fi
if ! git fetch "$REMOTE" "$BRANCH"; then
  log "update failed: fetch of $REMOTE/$BRANCH failed"
  exit 1
fi
if ! git merge --ff-only FETCH_HEAD; then
  log "update skipped: local branch is not a fast-forward; no reset was performed"
  exit 1
fi
log "code update complete from $REMOTE/$BRANCH; no job data was pushed"
