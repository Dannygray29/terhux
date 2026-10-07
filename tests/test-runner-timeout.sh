#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
ORIGIN="$TMP_DIR/origin.git"
mkdir -p "$HOME_DIR/spin" "$REPO_DIR/commands" "$REPO_DIR/results"
cp "$ROOT_DIR/terhux-exec.sh" "$REPO_DIR/terhux-exec.sh"
command -v npm >/dev/null || { echo 'SKIP: npm is not installed'; exit 0; }
command -v timeout >/dev/null || { echo 'SKIP: timeout is not installed'; exit 0; }

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git init --initial-branch=main "$REPO_DIR" >/dev/null
git -C "$REPO_DIR" config user.name 'Terhux Timeout Test'
git -C "$REPO_DIR" config user.email 'terhux-timeout@example.invalid'
printf 'test\n' > "$REPO_DIR/README.test"
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m 'test base' >/dev/null
git -C "$REPO_DIR" remote add origin "$ORIGIN"
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1

cat > "$HOME_DIR/spin/package.json" <<'JSON'
{"name":"timeout-test","version":"1.0.0","scripts":{"build":"node -e 'process.title=\"terhux-timeout-marker\"; while (true) {}'"}}
JSON
cat > "$REPO_DIR/commands/runaway-build.cmd" <<'CMD'
ACTION=project-build
PROJECT=spin
APPROVED=true
CMD

HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" TERHUX_ACTION_TIMEOUT_SECONDS=1 \
  bash "$ROOT_DIR/terhux-runner.sh" "$REPO_DIR/commands/runaway-build.cmd"
RESULT="$REPO_DIR/results/runaway-build.result"
[ -f "$RESULT" ] || { echo 'FAIL: runner did not publish a result locally' >&2; exit 1; }
grep -q '^STATUS=TIMEOUT$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: runaway build was not marked TIMEOUT' >&2; exit 1; }
grep -q '^EXIT_CODE=124$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: expected timeout exit code 124' >&2; exit 1; }
git --git-dir="$ORIGIN" show main:results/runaway-build.result | grep -q '^STATUS=TIMEOUT$' || { echo 'FAIL: timeout result was not pushed to the queue repository' >&2; exit 1; }
sleep 0.2
if pgrep -af '[t]erhux-timeout-marker' >/dev/null; then echo 'FAIL: runaway child process survived the timeout' >&2; exit 1; fi
echo 'PASS: runaway project build is stopped at its deadline and the TIMEOUT result is published.'
