#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
STATE_DIR="$TMP_DIR/state"
mkdir -p "$HOME_DIR" "$REPO_DIR" "$STATE_DIR/commands"
cp "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/terhux-runner.sh"
cp "$ROOT_DIR/terhux-exec.sh" "$REPO_DIR/terhux-exec.sh"

cat > "$STATE_DIR/commands/issue-201.cmd" <<'CMD'
ACTION=terhux-runtime-status
APPROVED=true
CMD
HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" TERHUX_STATE_DIR="$STATE_DIR" \
  bash "$REPO_DIR/terhux-runner.sh" "$STATE_DIR/commands/issue-201.cmd"
RESULT="$STATE_DIR/results/issue-201.result"
grep -q '^STATUS=SUCCESS$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: runtime status action did not succeed' >&2; exit 1; }
grep -q 'TERHUX_RUNTIME_STATUS_V1' "$RESULT" || { cat "$RESULT"; echo 'FAIL: runtime diagnostics were not captured locally' >&2; exit 1; }
echo 'PASS: runtime-status diagnostics are captured in local state without a Git commit.'
