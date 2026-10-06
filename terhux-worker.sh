#!/data/data/com.termux/files/usr/bin/bash
REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RUNNING_DIR="$COMMAND_DIR/.running"
RESULT_DIR="$REPO_DIR/results"
TASK_DIR="$REPO_DIR/tasks"
LOCK_DIR="$REPO_DIR/.locks"
SYNC_LOCK="$LOCK_DIR/git-sync.lock"
mkdir -p "$RUNNING_DIR" "$RESULT_DIR" "$TASK_DIR" "$LOCK_DIR"
COMMAND_FILE=""
PROJECT=""
PROJECT_LOCK=""
trap 'if [ -n "$PROJECT_LOCK" ]; then rmdir "$PROJECT_LOCK" 2>/dev/null || true; fi' EXIT INT TERM
cd "$REPO_DIR" || exit 1
git pull --quiet --rebase 2>/dev/null || true
while IFS= read -r candidate; do
  candidate_project=$(sed -n 's/^PROJECT=//p' "$candidate" | head -n 1)
  [ -n "$candidate_project" ] || continue
  safe_project=$(printf '%s' "$candidate_project" | tr -c 'A-Za-z0-9._-' '_')
  candidate_lock="$LOCK_DIR/project-$safe_project.lock"
  if mkdir "$candidate_lock" 2>/dev/null; then
    COMMAND_FILE="$candidate"
    PROJECT="$candidate_project"
    PROJECT_LOCK="$candidate_lock"
    break
  fi
done < <(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | sort)
[ -n "$COMMAND_FILE" ] || exit 0
CLAIMED="$RUNNING_DIR/$(basename "$COMMAND_FILE")"
if ! mv "$COMMAND_FILE" "$CLAIMED" 2>/dev/null; then exit 0; fi
COMMAND_ID=$(basename "$CLAIMED" .cmd)
STATE_FILE="$TASK_DIR/$COMMAND_ID.state"
CREATED=$(sed -n 's/^CREATED=//p' "$STATE_FILE" | head -n1)
[ -n "$CREATED" ] || CREATED=$(date +%s)
cat > "$STATE_FILE" <<EOF
ID=$COMMAND_ID
PROJECT=$PROJECT
STATUS=RUNNING
APPROVAL=APPROVED
CREATED=$CREATED
STARTED=$(date +%s)
EOF
TERHUX_NO_SYNC=1 "$REPO_DIR/terhux-runner.sh" "$CLAIMED"
RUN_EXIT=$?
RESULT="$RESULT_DIR/$COMMAND_ID.result"
STATUS=$(sed -n 's/^STATUS=//p' "$RESULT" 2>/dev/null | head -n1)
[ -n "$STATUS" ] || STATUS="ERROR"
STARTED=$(sed -n 's/^STARTED=//p' "$STATE_FILE" | head -n1)
cat > "$STATE_FILE" <<EOF
ID=$COMMAND_ID
PROJECT=$PROJECT
STATUS=$STATUS
APPROVAL=APPROVED
CREATED=$CREATED
STARTED=$STARTED
UPDATED=$(date +%s)
EXIT_CODE=$RUN_EXIT
RESULT_FILE=results/$COMMAND_ID.result
EOF
while ! mkdir "$SYNC_LOCK" 2>/dev/null; do sleep 1; done
git -C "$REPO_DIR" add commands results tasks >/dev/null 2>&1 || true
git -C "$REPO_DIR" commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
git -C "$REPO_DIR" pull --rebase --quiet 2>/dev/null || true
git -C "$REPO_DIR" push --quiet 2>/dev/null || true
rmdir "$SYNC_LOCK" 2>/dev/null || true
exit "$RUN_EXIT"
