#!/data/data/com.termux/files/usr/bin/bash
REPO_DIR="$HOME/terhux/repo"
REGISTRY="$REPO_DIR/projects.conf"
mkdir -p "$REPO_DIR"
touch "$REGISTRY"

usage() {
  echo "Usage: $0 add <project-id> <absolute-path>"
  echo "       $0 list"
  echo "       $0 remove <project-id>"
}

case "${1:-}" in
  add)
    ID="${2:-}"
    PATH_ARG="${3:-}"
    [ -n "$ID" ] && [ -n "$PATH_ARG" ] || { usage; exit 2; }
    case "$ID" in *[!a-zA-Z0-9_-]*) echo "Invalid project id."; exit 2;; esac
    case "$PATH_ARG" in /*) ;; *) echo "Path must be absolute."; exit 2;; esac
    [ -d "$PATH_ARG" ] || { echo "Directory does not exist: $PATH_ARG"; exit 1; }
    [ -d "$PATH_ARG/.git" ] || { echo "Project must be a Git repository: $PATH_ARG"; exit 1; }
    TMP="$REGISTRY.tmp"
    grep -v "^$ID|" "$REGISTRY" > "$TMP" 2>/dev/null || true
    printf '%s|%s\n' "$ID" "$PATH_ARG" >> "$TMP"
    mv "$TMP" "$REGISTRY"
    echo "Registered project: $ID -> $PATH_ARG"
    ;;
  list)
    echo "TERHUX PROJECTS"
    grep -v '^#' "$REGISTRY" | grep -v '^$' || true
    ;;
  remove)
    ID="${2:-}"
    [ -n "$ID" ] || { usage; exit 2; }
    grep -q "^$ID|" "$REGISTRY" || { echo "Project not registered: $ID"; exit 1; }
    grep -v "^$ID|" "$REGISTRY" > "$REGISTRY.tmp"
    mv "$REGISTRY.tmp" "$REGISTRY"
    echo "Removed project: $ID"
    ;;
  *) usage; exit 2;;
esac
