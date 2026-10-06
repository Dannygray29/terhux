#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
INTERVAL="${TERHUX_INTERVAL:-3}"
GIT_RETRY="${TERHUX_GIT_RETRY:-5}"

mkdir -p "$REPO_DIR/commands" "$REPO_DIR/results"

while true; do
  # Never exit because the network or GitHub is temporarily unavailable.
  git_ok=false
  for attempt in $(seq 1 "$GIT_RETRY"); do
    if git -C "$REPO_DIR" pull --rebase --autostash >/dev/null 2>&1; then
      git_ok=true
      break
    fi
    sleep "$INTERVAL"
  done

  if [ "$git_ok" = "true" ]; then
    command_file=$(find "$REPO_DIR/commands" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
    if [ -n "$command_file" ]; then
      "$REPO_DIR/terhux-runner.sh" "$command_file" >/dev/null 2>&1 || true
    fi
  fi

  sleep "$INTERVAL"
done
