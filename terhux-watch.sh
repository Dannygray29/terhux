#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
INTERVAL="${TERHUX_INTERVAL:-3}"

mkdir -p "$REPO_DIR/commands" "$REPO_DIR/results"

while true; do
  git -C "$REPO_DIR" pull --rebase --autostash >/dev/null 2>&1 || true

  command_file=$(find "$REPO_DIR/commands" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
  if [ -n "$command_file" ]; then
    "$REPO_DIR/terhux-runner.sh" "$command_file" >/dev/null 2>&1 || true
  fi

  sleep "$INTERVAL"
done
