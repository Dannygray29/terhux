#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"

mkdir -p "$COMMAND_DIR" "$RESULT_DIR"

command_file="${1:-}"
if [ -z "$command_file" ]; then
  command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n 1)
fi

[ -n "$command_file" ] && [ -f "$command_file" ] || exit 0

id=$(basename "$command_file" .cmd)
raw=$(cat "$command_file")

approved=$(printf '%s\n' "$raw" | sed -n 's/^APPROVED=//p' | head -n1)
workdir=$(printf '%s\n' "$raw" | sed -n 's/^WORKDIR=//p' | head -n1)
command_b64=$(printf '%s\n' "$raw" | sed -n 's/^COMMAND_B64=//p' | head -n1)
command=$(printf '%s\n' "$raw" | sed -n 's/^COMMAND=//p' | head -n1)

status=SUCCESS
exit_code=0
stdout=""
stderr=""

if [ "$approved" != "true" ]; then
  status=BLOCKED
  stderr="APPROVED=true is required."
elif [ -n "$command_b64" ]; then
  command=$(printf '%s' "$command_b64" | base64 -d 2>/dev/null) || {
    status=ERROR
    exit_code=1
    stderr="Invalid COMMAND_B64."
  }
fi

if [ "$status" = "SUCCESS" ] && [ -z "$command" ]; then
  status=BLOCKED
  stderr="COMMAND or COMMAND_B64 is required."
fi

if [ "$status" = "SUCCESS" ]; then
  if [ -n "$workdir" ]; then
    case "$workdir" in
      /*) ;;
      *) workdir="$HOME/$workdir" ;;
    esac
    [ -d "$workdir" ] || {
      status=ERROR
      exit_code=1
      stderr="WORKDIR does not exist: $workdir"
    }
  else
    workdir="$HOME"
  fi
fi

if [ "$status" = "SUCCESS" ]; then
  stdout_file="/tmp/terhux-$id.out"
  stderr_file="/tmp/terhux-$id.err"
  : > "$stdout_file"
  : > "$stderr_file"

  cd "$workdir" 2>"$stderr_file" || {
    status=ERROR
    exit_code=$?
  }

  if [ "$status" = "SUCCESS" ]; then
    bash -c "$command" >"$stdout_file" 2>"$stderr_file"
    exit_code=$?
    [ "$exit_code" -eq 0 ] || status=ERROR
  fi

  stdout=$(cat "$stdout_file" 2>/dev/null)
  stderr=$(cat "$stderr_file" 2>/dev/null)
  rm -f "$stdout_file" "$stderr_file"
fi

{
  echo "TERHUX_RESULT_V1"
  echo "ID=$id"
  echo "STATUS=$status"
  echo "EXIT_CODE=$exit_code"
  echo "WORKDIR=$workdir"
  echo "TIME=$(date +%s)"
  echo "STDOUT_BEGIN"
  printf '%s\n' "$stdout"
  echo "STDOUT_END"
  echo "STDERR_BEGIN"
  printf '%s\n' "$stderr"
  echo "STDERR_END"
} > "$RESULT_DIR/$id.result"

rm -f "$command_file"

git -C "$REPO_DIR" add commands results >/dev/null 2>&1 || true
git -C "$REPO_DIR" commit -m "Terhux result: $id" >/dev/null 2>&1 || true
git -C "$REPO_DIR" pull --rebase --autostash >/dev/null 2>&1 || true
git -C "$REPO_DIR" push >/dev/null 2>&1 || true
