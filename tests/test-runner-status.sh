#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
ORIGIN="$TMP_DIR/origin.git"
mkdir -p "$HOME_DIR" "$REPO_DIR/commands" "$REPO_DIR/results"
cp "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/terhux-runner.sh"
cp "$ROOT_DIR/terhux-exec.sh" "$REPO_DIR/terhux-exec.sh"

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git init --initial-branch=main "$REPO_DIR" >/dev/null
git -C "$REPO_DIR" config user.name 'Terhux Status Test'
git -C "$REPO_DIR" config user.email 'terhux-status@example.invalid'
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m 'test base' >/dev/null
git -C "$REPO_DIR" remote add origin "$ORIGIN"
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1

cat > "$REPO_DIR/commands/issue-201.cmd" <<'CMD'
ACTION=terhux-runtime-status
APPROVED=true
CMD
HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" bash "$REPO_DIR/terhux-runner.sh" "$REPO_DIR/commands/issue-201.cmd"
RESULT="$TMP_DIR/result"
git --git-dir="$ORIGIN" show main:results/issue-201.result > "$RESULT"
grep -q '^STATUS=SUCCESS$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: runtime status action did not succeed' >&2; exit 1; }
grep -q 'TERHUX_RUNTIME_STATUS_V1' "$RESULT" || { cat "$RESULT"; echo 'FAIL: runtime diagnostics were not captured in the result' >&2; exit 1; }
echo 'PASS: runtime-status diagnostics are captured and published.'
