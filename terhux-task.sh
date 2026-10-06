#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"
TASK_DIR="$REPO_DIR/tasks"
mkdir -p "$COMMAND_DIR" "$RESULT_DIR" "$TASK_DIR"

usage() {
  echo "Usage:"
  echo "  $0 create <task-id> <project> <action> [path] [content]"
  echo "  $0 list"
  echo "  $0 status <task-id>"
  echo "  $0 cancel <task-id>"
}

case "${1:-}" in
  create)
    ID="${2:-}"; PROJECT="${3:-}"; ACTION="${4:-}"; PATH_ARG="${5:-}"; CONTENT="${6:-}"
    if [ -z "$ID" ] || [ -z "$PROJECT" ] || [ -z "$ACTION" ]; then usage; exit 2; fi
    if [ -e "$COMMAND_DIR/$ID.cmd" ] || [ -e "$COMMAND_DIR/.running/$ID.cmd" ] || [ -e "$RESULT_DIR/$ID.result" ]; then
      echo "Task already exists: $ID"; exit 1
    fi
    {
      echo "ACTION=$ACTION"
      echo "PROJECT=$PROJECT"
      [ -n "$PATH_ARG" ] && echo "PATH=$PATH_ARG"
      [ -n "$CONTENT" ] && echo "CONTENT=$CONTENT"
      echo "APPROVED=true"
    } > "$COMMAND_DIR/$ID.cmd"
    {
      echo "ID=$ID"
      echo "PROJECT=$PROJECT"
      echo "ACTION=$ACTION"
      echo "STATUS=QUEUED"
      echo "CREATED=$(date +%s)"
    } > "$TASK_DIR/$ID.state"
    echo "Created task: $ID"
    ;;
  list)
    printf '%-24s %-14s %-12s %-18s\n' "TASK" "PROJECT" "STATUS" "UPDATED"
    for f in "$TASK_DIR"/*.state; do
      [ -f "$f" ] || continue
      ID=$(basename "$f" .state)
      PROJECT=$(sed -n 's/^PROJECT=//p' "$f" | head -n1)
      STATUS=$(sed -n 's/^STATUS=//p' "$f" | head -n1)
      UPDATED=$(sed -n 's/^UPDATED=//p' "$f" | head -n1)
      [ -z "$UPDATED" ] && UPDATED=$(sed -n 's/^CREATED=//p' "$f" | head -n1)
      printf '%-24s %-14s %-12s %-18s\n' "$ID" "$PROJECT" "$STATUS" "$UPDATED"
    done
    ;;
  status)
    ID="${2:-}"
    [ -n "$ID" ] || { usage; exit 2; }
    if [ -f "$TASK_DIR/$ID.state" ]; then
      cat "$TASK_DIR/$ID.state"
    elif [ -f "$RESULT_DIR/$ID.result" ]; then
      cat "$RESULT_DIR/$ID.result"
    else
      echo "Task not found: $ID"; exit 1
    fi
    ;;
  cancel)
    ID="${2:-}"
    [ -n "$ID" ] || { usage; exit 2; }
    if [ -f "$COMMAND_DIR/$ID.cmd" ]; then
      rm -f "$COMMAND_DIR/$ID.cmd"
      {
        echo "ID=$ID"
        echo "STATUS=CANCELLED"
        echo "UPDATED=$(date +%s)"
      } > "$TASK_DIR/$ID.state"
      echo "Cancelled task: $ID"
    else
      echo "Task is already running or finished; it was not cancelled."
      exit 1
    fi
    ;;
  *)
    usage
    exit 2
    ;;
esac
