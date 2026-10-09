#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
COMMAND_DIR="$STATE_DIR/commands"
RESULT_DIR="$STATE_DIR/results"
mkdir -p "$COMMAND_DIR" "$RESULT_DIR"
command_file="${1:-}"
[ -n "$command_file" ] || command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
[ -n "$command_file" ] && [ -f "$command_file" ] || exit 0
id=$(basename "$command_file" .cmd)
[[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] || exit 125
raw=$(cat "$command_file")
action=$(printf '%s\n' "$raw" | sed -n 's/^ACTION=//p' | head -n1)
approved=$(printf '%s\n' "$raw" | sed -n 's/^APPROVED=//p' | head -n1)
command_b64=$(printf '%s\n' "$raw" | sed -n 's/^COMMAND_B64=//p' | head -n1)
status=SUCCESS
exit_code=0
stdout=""
stderr=""

run_timed_action() {
  local workdir="$1"
  shift
  stdout=$(bash "$REPO_DIR/terhux-exec.sh" "$workdir" "$@" 2>&1)
  exit_code=$?
  case "$exit_code" in
    124|137)
      status=TIMEOUT
      stderr="Action exceeded its wall-time limit and was terminated. Check for partial external effects before retrying."
      ;;
    122)
      status=OUTPUT_LIMIT
      stderr="Action exceeded the captured-output limit and was interrupted. Check for partial external effects before retrying."
      ;;
    *)
      [ "$exit_code" -eq 0 ] || status=ERROR
      ;;
  esac
}

if [ "$approved" != true ]; then
  status=BLOCKED
  exit_code=1
  stderr="APPROVED=true is required."
elif [ -z "$action" ]; then
  status=BLOCKED
  exit_code=1
  stderr="ACTION is required."
else
  case "$action" in
    shell-command)
      if [ -z "$command_b64" ]; then
        status=BLOCKED
        exit_code=1
        stderr="Shell command payload is missing."
      else
        shell_command=$(printf '%s' "$command_b64" | base64 -d 2>/dev/null) || {
          status=BLOCKED; exit_code=1; stderr="Shell command payload is invalid."
        }
        if [ "$status" = SUCCESS ]; then
          if [ -z "${shell_command:-}" ]; then
            status=BLOCKED; exit_code=1; stderr="Shell command is empty."
          else
            # A trusted, Triage-authorized agent gets the normal Termux user's shell.
            run_timed_action "$HOME" bash -lc "$shell_command"
          fi
        fi
      fi
      ;;
    terhux-runner-version)
      stdout="TERHUX_RUNNER_OK"
      ;;
    terhux-runtime-status)
      stdout=$(
        {
          echo "TERHUX_RUNTIME_STATUS_V1"
          echo "SUPERVISOR:"
          pgrep -af "[t]erhux-supervisor.sh" || true
          echo "WATCHER:"
          pgrep -af "[t]erhux-watch.sh" || true
          echo "ISSUE_WORKER:"
          pgrep -af "[t]erhux-issue-worker.py" || true
          echo "LEGACY_WORKER:"
          pgrep -af "[t]erhux-worker.sh" || true
          echo "LEGACY_AI_AGENT:"
          pgrep -af "[t]erhux-ai-agent.js" || true
          echo "TERHUX2:"
          pgrep -af "[t]erhux2-runner.sh" || true
          echo "RUNIT_TERHUX:"
          command -v sv >/dev/null 2>&1 && sv status terhux 2>&1 || echo unavailable
          echo "RUNIT_TERHUX2:"
          command -v sv >/dev/null 2>&1 && sv status terhux2 2>&1 || echo unavailable
        }
      )
      ;;
    *)
      status=BLOCKED
      exit_code=1
      stderr="Legacy structured action is retired. Send a raw shell command in the GitHub issue body."
      ;;
  esac
fi

RESULT_FILE="$RESULT_DIR/$id.result"
RESULT_TMP=$(mktemp "$RESULT_DIR/.$id.result.XXXXXX") || exit 125
{
  echo TERHUX_RESULT_V2
  echo "ID=$id"
  echo "ACTION=$action"
  echo "APPROVED=$approved"
  echo "STATUS=$status"
  echo "EXIT_CODE=$exit_code"
  echo "TIME=$(date +%s)"
  echo "STDOUT_BEGIN:$id"
  printf '%s\n' "$stdout"
  echo "STDOUT_END:$id"
  echo "STDERR_BEGIN:$id"
  printf '%s\n' "$stderr"
  echo "STDERR_END:$id"
} >"$RESULT_TMP"
chmod 600 "$RESULT_TMP"
mv -f "$RESULT_TMP" "$RESULT_FILE"
rm -f "$command_file"
