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
  status=SUCCESS; exit_code=0; stdout=""; stderr=""
  if [ "$approved" != "true" ]; then
    status=BLOCKED; exit_code=1; stderr="APPROVED=true is required."
  else
    case "$action" in
      terhux2-version) stdout="TERHUX2_OK" ;;
      terhux2-ping) stdout="TERHUX2_PONG" ;;
      terhux2-review-project)
        if [ "$project" = "grey" ]; then
          stdout="GREY_REVIEW_QUEUED"
          stdout="$stdout"
      *) status=BLOCKED; exit_code=1; stderr="Action is not allowlisted." ;;
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
\n'"PROJECT=grey"
          stdout="$stdout"
      *) status=BLOCKED; exit_code=1; stderr="Action is not allowlisted." ;;
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
\n'"REVIEW_MODE=static-project-review"
        else
          status=BLOCKED; exit_code=1; stderr="Project is not allowlisted."
        fi
        ;;
      *) status=BLOCKED; exit_code=1; stderr="Action is not allowlisted." ;;
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
