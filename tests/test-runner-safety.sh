#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
ORIGIN="$TMP_DIR/origin.git"
mkdir -p "$HOME_DIR/project" "$REPO_DIR/commands" "$REPO_DIR/results"
printf '%s\n' 'MUST_NOT_BE_READ' > "$TMP_DIR/outside-secret.txt"
cp "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/terhux-runner.sh"
cp "$ROOT_DIR/terhux-exec.sh" "$REPO_DIR/terhux-exec.sh"

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git init --initial-branch=main "$REPO_DIR" >/dev/null
git -C "$REPO_DIR" config user.name 'Terhux Safety Test'
git -C "$REPO_DIR" config user.email 'terhux-safety@example.invalid'
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m 'test base' >/dev/null
git -C "$REPO_DIR" remote add origin "$ORIGIN"
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1

cat > "$REPO_DIR/commands/traversal.cmd" <<'CMD'
ACTION=project-read-file
PROJECT=..
PATH=outside-secret.txt
APPROVED=true
CMD
HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" bash "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/commands/traversal.cmd"
RESULT="$REPO_DIR/results/traversal.result"
grep -q '^STATUS=BLOCKED$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: PROJECT=.. was not blocked' >&2; exit 1; }
! grep -q 'MUST_NOT_BE_READ' "$RESULT" || { echo 'FAIL: runner read outside the project home' >&2; exit 1; }
git --git-dir="$ORIGIN" show main:results/traversal.result | grep -q '^STATUS=BLOCKED$' || { echo 'FAIL: safe rejection was not published' >&2; exit 1; }
echo 'PASS: parent-directory project traversal is blocked and no outside file content is returned.'
