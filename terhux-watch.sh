#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
INTERVAL="${TERHUX_INTERVAL:-5}"

mkdir -p "$COMMAND_DIR" "$REPO_DIR/results"

while true; do
  cd "$REPO_DIR" 2>/dev/null || { sleep "$INTERVAL"; continue; }

  # Sync GitHub. Keep local result commits; never hard-reset.
  if ! git pull --rebase --autostash origin main >/dev/null 2>&1; then
    # The bridge must recover from stale local state instead of going offline.
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git reset --hard origin/main >/dev/null 2>&1 || true
    sleep "$INTERVAL"
    continue
  fi

  command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)

  if [ -n "$command_file" ]; then
    "$REPO_DIR/terhux-runner.sh" "$command_file" >/dev/null 2>&1 || true
  fi

  sleep "$INTERVAL"
done
