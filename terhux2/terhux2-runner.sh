#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
COMMANDS="$ROOT/commands"
RESULTS="$ROOT/results"
mkdir -p "$COMMANDS" "$RESULTS"

for cmd in "$COMMANDS"/*.cmd; do
  [ -f "$cmd" ] || continue

  id="$(basename "$cmd" .cmd)"
  approved="$(grep '^APPROVED=' "$cmd" | cut -d= -f2-)"
  action="$(grep '^ACTION=' "$cmd" | cut -d= -f2-)"
  project="$(grep '^PROJECT=' "$cmd" | cut -d= -f2-)"

  status=SUCCESS
  exit_code=0
  stdout=""
  stderr=""

  if [ "$approved" != "true" ]; then
    status=BLOCKED
    exit_code=1
    stderr="APPROVED=true is required."
  else
    case "$action" in
      terhux2-version)
        stdout="TERHUX2_OK"
        ;;
      terhux2-ping)
        stdout="TERHUX2_PONG"
        ;;
      terhux2-review-project)
        if [ "$project" != "grey" ]; then
          status=BLOCKED
          exit_code=1
          stderr="Project is not allowlisted."
        else
          PROJECT_ROOT="$HOME/grey"
          if [ ! -d "$PROJECT_ROOT/.git" ]; then
            status=FAILED
            exit_code=1
            stderr="Allowlisted GREY project is not installed at $HOME/grey."
          else
            branch="$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)"
            head="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
            dirty="$(git -C "$PROJECT_ROOT" status --short 2>/dev/null | head -n 20)"
            package_ok="NO"
            [ -f "$PROJECT_ROOT/package.json" ] && package_ok="YES"
            tsconfig_ok="NO"
            [ -f "$PROJECT_ROOT/tsconfig.json" ] && tsconfig_ok="YES"

            stdout="GREY_REVIEW_V1
PROJECT=grey
PATH=$HOME/grey
BRANCH=$branch
HEAD=$head
GIT_DIRTY_BEGIN
$dirty
GIT_DIRTY_END
PACKAGE_JSON=$package_ok
TSCONFIG_JSON=$tsconfig_ok
REVIEW_MODE=read-only-static"
          fi
        fi
        ;;
      *)
        status=BLOCKED
        exit_code=1
        stderr="Action is not allowlisted."
        ;;
    esac
  fi

  {
    echo "TERHUX2_RESULT_V1"
    echo "ID=$id"
    echo "ACTION=$action"
    echo "STATUS=$status"
    echo "EXIT_CODE=$exit_code"
    echo "STDOUT_BEGIN"
    printf '%s\n' "$stdout"
    echo "STDOUT_END"
    echo "STDERR_BEGIN"
    printf '%s\n' "$stderr"
    echo "STDERR_END"
  } > "$RESULTS/$id.result"

  rm -f "$cmd"
done
