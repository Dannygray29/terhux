#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/sync.log"
REMOTE="${TERHUX_REMOTE:-origin}"
BRANCH="${TERHUX_BRANCH:-main}"
RETRIES="${TERHUX_SYNC_RETRIES:-4}"
BASE_DELAY="${TERHUX_SYNC_BASE_DELAY:-1}"

mkdir -p "$LOG_DIR" 2>/dev/null || true
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"; }

cd "$REPO_DIR" 2>/dev/null || { log "repository unavailable: $REPO_DIR"; exit 1; }

# Recover edits/results left by a restart or a failed push before fetching.
# Only bridge queue/result files are staged; no reset/checkout discards local work.
git add -- commands results >>"$LOG_FILE" 2>&1 || { log 'git add failed'; exit 1; }
if ! git diff --cached --quiet -- commands results; then
  if ! git -c user.name='Terhux Bridge' -c user.email='terhux-bridge@users.noreply.github.com' \
      commit -m "Terhux: save queued requests and results" >>"$LOG_FILE" 2>&1; then
    log 'git commit failed; local files retained for retry'
    exit 1
  fi
fi

case "$RETRIES" in ''|*[!0-9]*) RETRIES=4;; esac
[ "$RETRIES" -gt 0 ] || RETRIES=1
case "$BASE_DELAY" in ''|*[!0-9]*) BASE_DELAY=1;; esac

attempt=1
delay="$BASE_DELAY"
while [ "$attempt" -le "$RETRIES" ]; do
  if git fetch "$REMOTE" "$BRANCH" >>"$LOG_FILE" 2>&1; then
    if git rebase FETCH_HEAD >>"$LOG_FILE" 2>&1; then
      if git push "$REMOTE" "HEAD:$BRANCH" >>"$LOG_FILE" 2>&1; then
        log "sync succeeded on attempt $attempt"
        exit 0
      fi
      git rebase --abort >>"$LOG_FILE" 2>&1 || true
    else
      log "rebase failed; local commit retained for later retry"
      git rebase --abort >>"$LOG_FILE" 2>&1 || true
    fi
  else
    log "fetch failed on attempt $attempt; local commit retained"
  fi

  if [ "$attempt" -lt "$RETRIES" ]; then
    sleep "$delay"
    delay=$((delay * 2))
  fi
  attempt=$((attempt + 1))
done

log "sync failed after $RETRIES attempts; retrying on next watcher cycle"
exit 1
