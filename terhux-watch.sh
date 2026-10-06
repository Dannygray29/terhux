#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RUNNING_DIR="$COMMAND_DIR/.running"
PID_DIR="$RUNNING_DIR/.pids"
INTERVAL="${TERHUX_INTERVAL:-3}"
GIT_RETRY="${TERHUX_GIT_RETRY:-5}"
RUN_TIMEOUT="${TERHUX_RUN_TIMEOUT:-900}"

mkdir -p "$COMMAND_DIR" "$RUNNING_DIR" "$PID_DIR" "$REPO_DIR/results"

while true; do
  # GitHub/network outages must never stop the bridge.
  git_ok=false
  for attempt in $(seq 1 "$GIT_RETRY"); do
    if git -C "$REPO_DIR" pull --rebase --autostash >/dev/null 2>&1; then
      git_ok=true
      break
    fi
    sleep "$INTERVAL"
  done

  # Reap finished jobs and recover commands whose runner died.
  for pidfile in "$PID_DIR"/*.pid; do
    [ -f "$pidfile" ] || continue
    pid=$(cat "$pidfile" 2>/dev/null || true)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$pidfile"
    fi
  done

  if [ "$git_ok" = "true" ]; then
    # Keep execution serialized so Git operations cannot race each other.
    if ! find "$PID_DIR" -maxdepth 1 -type f -name '*.pid' | grep -q .; then
      command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
      if [ -n "$command_file" ]; then
        name=$(basename "$command_file")
        claimed="$RUNNING_DIR/$name"
        if mv "$command_file" "$claimed" 2>/dev/null; then
          pidfile="$PID_DIR/$name.pid"
          (
            timeout "$RUN_TIMEOUT" "$REPO_DIR/terhux-runner.sh" "$claimed" >/dev/null 2>&1
            code=$?
            if [ "$code" -eq 124 ] && [ ! -f "$REPO_DIR/results/${name%.cmd}.result" ]; then
              {
                echo "TERHUX_RESULT_V1"
                echo "ID=${name%.cmd}"
                echo "ACTION=timeout"
                echo "PROJECT="
                echo "PATH="
                echo "APPROVED=true"
                echo "STATUS=ERROR"
                echo "EXIT_CODE=124"
                echo "TIME=$(date +%s)"
                echo "STDOUT_BEGIN"
                echo "Runner exceeded ${RUN_TIMEOUT}s and was terminated."
                echo "STDOUT_END"
                echo "STDERR_BEGIN"
                echo "The command was terminated by the Terhux watchdog."
                echo "STDERR_END"
              } > "$REPO_DIR/results/${name%.cmd}.result"
              rm -f "$claimed"
              git -C "$REPO_DIR" add results commands >/dev/null 2>&1 || true
              git -C "$REPO_DIR" commit -m "Terhux watchdog: ${name%.cmd}" >/dev/null 2>&1 || true
              git -C "$REPO_DIR" push >/dev/null 2>&1 || true
            fi
            rm -f "$pidfile"
          ) &
          echo $! > "$pidfile"
        fi
      fi
    fi
  fi

  sleep "$INTERVAL"
done
