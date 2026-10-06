#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
TASK="$REPO_DIR/terhux-task.sh"

usage() {
  echo "Terhux Controller"
  echo "  $0 submit <task-id> <project> <action> [path] [content]"
  echo "  $0 approve <task-id>"
  echo "  $0 reject <task-id>"
  echo "  $0 status <task-id>"
  echo "  $0 list"
}

case "${1:-}" in
  submit)
    shift
    exec "$TASK" create "$@"
    ;;
  approve)
    exec "$TASK" approve "${2:-}"
    ;;
  reject)
    exec "$TASK" reject "${2:-}"
    ;;
  status)
    exec "$TASK" status "${2:-}"
    ;;
  list)
    exec "$TASK" list
    ;;
  *)
    usage
    exit 2
    ;;
esac
