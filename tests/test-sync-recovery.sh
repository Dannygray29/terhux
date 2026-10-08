#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ORIGIN="$TMP_DIR/origin.git"
PHONE="$TMP_DIR/phone"
OWNER="$TMP_DIR/owner"

fail() { echo "FAIL: $*" >&2; exit 1; }

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git clone "$ORIGIN" "$PHONE" >/dev/null 2>&1
cd "$PHONE"
git config user.name 'Terhux Test'
git config user.email 'terhux-test@example.invalid'
mkdir -p commands results logs
echo 'base repository' > README.test
git add .
git commit -m 'test base' >/dev/null
git push -u origin main >/dev/null 2>&1
# Simulate a phone checkout with multiple configured merge branches.
git -C "$PHONE" config --add branch.main.merge refs/heads/legacy

# Simulate an action finishing on the phone while the GitHub network is down.
printf 'TERHUX_RESULT_V1\nID=issue-101\nSTATUS=SUCCESS\nEXIT_CODE=0\n' > "$PHONE/results/issue-101.result"
git -C "$PHONE" remote set-url origin "$TMP_DIR/unavailable.git"
if TERHUX_REPO_DIR="$PHONE" TERHUX_SYNC_RETRIES=2 TERHUX_SYNC_BASE_DELAY=0 \
  bash "$ROOT_DIR/terhux-sync.sh"; then
  fail 'sync unexpectedly succeeded with an unavailable remote'
fi
[ -f "$PHONE/results/issue-101.result" ] || fail 'result was lost during outage'

# Simulate an owner-side documentation update arriving while the phone is offline.
git clone "$ORIGIN" "$OWNER" >/dev/null 2>&1
git -C "$OWNER" config user.name 'Owner Test'
git -C "$OWNER" config user.email 'owner-test@example.invalid'
printf 'updated while phone was offline\n' >> "$OWNER/README.test"
git -C "$OWNER" add README.test
git -C "$OWNER" commit -m 'concurrent owner update' >/dev/null
git -C "$OWNER" push origin main >/dev/null 2>&1

# Reconnect: the phone's result and the concurrent remote update must both survive.
git -C "$PHONE" remote set-url origin "$ORIGIN"
TERHUX_REPO_DIR="$PHONE" TERHUX_SYNC_RETRIES=3 TERHUX_SYNC_BASE_DELAY=0 \
  bash "$ROOT_DIR/terhux-sync.sh"

VERIFY="$TMP_DIR/verify"
git clone "$ORIGIN" "$VERIFY" >/dev/null 2>&1
[ -f "$VERIFY/results/issue-101.result" ] || fail 'local result was not published after reconnect'
grep -q 'updated while phone was offline' "$VERIFY/README.test" || fail 'remote update was lost during recovery'
echo 'PASS: local results survive offline periods and are rebased with concurrent remote updates.'
