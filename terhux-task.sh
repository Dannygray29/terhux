#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RUNNING_DIR="$COMMAND_DIR/.running"
RESULT_DIR="$REPO_DIR/results"
TASK_DIR="$REPO_DIR/tasks"
mkdir -p "$COMMAND_DIR" "$RUNNING_DIR" "$RESULT_DIR" "$TASK_DIR"

usage() {
  echo "Usage:"
  echo "  $0 create <task-id> <project> <action> [path] [content]"
  echo "  $0 approve <task-id>"
  echo "  $0 reject <task-id>"
  echo "  $0 list"
  echo "  $0 status <task-id>"
  echo "  $0 cancel <task-id>"
}

valid_id() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._-]+$'; }

case "${1:-}" in
  create)
    ID="${2:-}"; PROJECT="${3:-}"; ACTION="${4:-}"; PATH_ARG="${5:-}"; CONTENT="${6:-}"
    if [ -z "$ID" ] || [ -z "$PROJECT" ] || [ -z "$ACTION" ] || ! valid_id "$ID"; then usage; exit 2; fi
    if [ -e "$COMMAND_DIR/$ID.cmd" ] || [ -e "$RUNNING_DIR/$ID.cmd" ] || [ -e "$RESULT_DIR/$ID.result" ] || [ -e "$TASK_DIR/$ID.state" ]; then
      echo "Task already exists: $ID"; exit 1
    fi
    {
      echo "ID=$ID"
      echo "PROJECT=$PROJECT"
      echo "ACTION=$ACTION"
      echo "STATUS=QUEUED"
      echo "APPROVAL=PENDING"
      echo "CREATED=$(date +%s)"
    } > "$TASK_DIR/$ID.state"
    {
      echo "ACTION=$ACTION"
      echo "PROJECT=$PROJECT"
      [ -n "$PATH_ARG" ] && echo "PATH=$PATH_ARG"
      [ -n "$CONTENT" ] && echo "CONTENT=$CONTENT"
      echo "APPROVED=false"
    } > "$TASK_DIR/$ID.pending"
    echo "Created task: $ID (approval pending)"
    ;;
  approve)
    ID="${2:-}"; [ -n "$ID" ] || { usage; exit 2; }
    PENDING="$TASK_DIR/$ID.pending"
    STATE="$TASK_DIR/$ID.state"
    [ -f "$PENDING" ] || { echo "No pending task found: $ID"; exit 1; }
    sed '/^APPROVED=/d' "$PENDING" > "$COMMAND_DIR/$ID.cmd"
    echo "APPROVED=true" >> "$COMMAND_DIR/$ID.cmd"
    rm -f "$PENDING"
    sed -i 's/^APPROVAL=.*/APPROVAL=APPROVED/' "$STATE"
    echo "Approved task: $ID"
    ;;
  reject)
    ID="${2:-}"; [ -n "$ID" ] || { usage; exit 2; }
    PENDING="$TASK_DIR/$ID.pending"; STATE="$TASK_DIR/$ID.state"
    [ -f "$PENDING" ] || { echo "No pending task found: $ID"; exit 1; }
    rm -f "$PENDING"
    sed -i 's/^STATUS=.*/STATUS=REJECTED/; s/^APPROVAL=.*/APPROVAL=REJECTED/' "$STATE"
    echo "Rejected task: $ID"
    ;;
  list)
    printf '%-24s %-14s %-12s %-12s %-18s\n' "TASK" "PROJECT" "STATUS" "APPROVAL" "UPDATED"
    for f in "$TASK_DIR"/*.state; do
      [ -f "$f" ] || continue
      ID=$(basename "$f" .state)
      PROJECT=$(sed -n 's/^PROJECT=//p' "$f" | head -n1)
      STATUS=$(sed -n 's/^STATUS=//p' "$f" | head -n1)
      APPROVAL=$(sed -n 's/^APPROVAL=//p' "$f" | head -n1)
      UPDATED=$(sed -n 's/^UPDATED=//p' "$f" | head -n1)
      [ -n "$UPDATED" ] || UPDATED=$(sed -n 's/^CREATED=//p' "$f" | head -n1)
      printf '%-24s %-14s %-12s %-12s %-18s\n' "$ID" "$PROJECT" "$STATUS" "$APPROVAL" "$UPDATED"
    done
    ;;
  status)
    ID="${2:-}"; [ -n "$ID" ] || { usage; exit 2; }
    if [ -f "$TASK_DIR/$ID.state" ]; then
      cat "$TASK_DIR/$ID.state"
      [ -f "$TASK_DIR/$ID.pending" ] && echo "COMMAND_STATE=PENDING_APPROVAL"
    elif [ -f "$RESULT_DIR/$ID.result" ]; then
      cat "$RESULT_DIR/$ID.result"
    else
      echo "Task not found: $ID"; exit 1
    fi
    ;;
  cancel)
    ID="${2:-}"; [ -n "$ID" ] || { usage; exit 2; }
    if [ -f "$COMMAND_DIR/$ID.cmd" ]; then
      rm -f "$COMMAND_DIR/$ID.cmd"
      sed -i 's/^STATUS=.*/STATUS=CANCELLED/; s/^APPROVAL=.*/APPROVAL=CANCELLED/' "$TASK_DIR/$ID.state"
      echo "Cancelled task: $ID"
    elif [ -f "$TASK_DIR/$ID.pending" ]; then
      rm -f "$TASK_DIR/$ID.pending"
      sed -i 's/^STATUS=.*/STATUS=CANCELLED/; s/^APPROVAL=.*/APPROVAL=CANCELLED/' "$TASK_DIR/$ID.state"
      echo "Cancelled task: $ID"
    else
      echo "Task is already running or finished; it was not cancelled."
      exit 1
    fi
    ;;
  *) usage; exit 2 ;;
esac
