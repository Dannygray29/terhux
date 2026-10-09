#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
STATE_DIR="$TMP_DIR/state"
mkdir -p "$HOME_DIR" "$REPO_DIR" "$STATE_DIR/commands"
printf '%s\n' 'MUST_NOT_BE_READ' > "$TMP_DIR/outside-secret.txt"
cp "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/terhux-runner.sh"
cp "$ROOT_DIR/terhux-exec.sh" "$REPO_DIR/terhux-exec.sh"

cat > "$STATE_DIR/commands/retired-action.cmd" <<'CMD'
ACTION=project-read-file
PROJECT=..
PATH=outside-secret.txt
APPROVED=true
CMD
HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" TERHUX_STATE_DIR="$STATE_DIR" \
  bash "$REPO_DIR/terhux-runner.sh" "$STATE_DIR/commands/retired-action.cmd"
RESULT="$STATE_DIR/results/retired-action.result"
grep -q '^STATUS=BLOCKED$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: retired structured action was not blocked' >&2; exit 1; }
grep -q 'Legacy structured action is retired' "$RESULT" || { cat "$RESULT"; echo 'FAIL: retirement reason was not recorded' >&2; exit 1; }
! grep -q 'MUST_NOT_BE_READ' "$RESULT" || { echo 'FAIL: unsupported structured action returned outside file content' >&2; exit 1; }
echo 'PASS: obsolete structured project actions are blocked; new requests use the unrestricted raw shell.'
