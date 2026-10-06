#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"
INTERVAL="${TERHUX_INTERVAL:-5}"

mkdir -p "$COMMAND_DIR" "$RESULT_DIR"

while true; do
  cd "$REPO_DIR" 2>/dev/null || { sleep "$INTERVAL"; continue; }

  # Fast, deterministic GitHub sync. Discard only local bridge state so a
  # stale rebase can never wedge the watcher.
  if git fetch origin main >/dev/null 2>&1; then
    git reset --hard origin/main >/dev/null 2>&1 || true
  else
    sleep "$INTERVAL"
    continue
  fi

  command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)

  if [ -n "$command_file" ] && [ -f "$command_file" ]; then
    "$REPO_DIR/terhux-runner.sh" "$command_file" >/dev/null 2>&1 || true
  fi

  sleep "$INTERVAL"
done
