#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ORIGIN="$TMP_DIR/origin.git"
OWNER="$TMP_DIR/owner"
PHONE="$TMP_DIR/phone"
STATE="$TMP_DIR/phone-state"
VERIFY="$TMP_DIR/verify"
fail() { echo "FAIL: $*" >&2; exit 1; }

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git init --initial-branch=main "$OWNER" >/dev/null
git -C "$OWNER" config user.name 'Owner Test'
git -C "$OWNER" config user.email 'owner-test@example.invalid'
printf 'base repository\n' > "$OWNER/README.test"
git -C "$OWNER" add README.test
git -C "$OWNER" commit -m 'test base' >/dev/null
git -C "$OWNER" remote add origin "$ORIGIN"
git -C "$OWNER" push -u origin main >/dev/null 2>&1
git clone "$ORIGIN" "$PHONE" >/dev/null 2>&1
git -C "$PHONE" config user.name 'Terhux Phone'
git -C "$PHONE" config user.email 'terhux-phone@example.invalid'
# Reproduce the phone's old multi-merge-ref configuration that broke git pull.
git -C "$PHONE" config --add branch.main.merge refs/heads/legacy
mkdir -p "$STATE/results"
printf 'issue result persists outside Git\n' > "$STATE/results/issue-101.result"

# A failed update must not touch local job state.
git -C "$PHONE" remote set-url origin "$TMP_DIR/unavailable.git"
if TERHUX_REPO_DIR="$PHONE" TERHUX_STATE_DIR="$STATE" bash "$ROOT_DIR/terhux-sync.sh" >/dev/null 2>&1; then
  fail 'update unexpectedly succeeded with an unavailable remote'
fi
[ -f "$STATE/results/issue-101.result" ] || fail 'local result was lost during network outage'

# A concurrent owner change should be a clean fast-forward, not a pull/rebase conflict.
printf 'owner update while phone was offline\n' >> "$OWNER/README.test"
git -C "$OWNER" add README.test
git -C "$OWNER" commit -m 'owner update' >/dev/null
git -C "$OWNER" push origin main >/dev/null 2>&1
git -C "$PHONE" remote set-url origin "$ORIGIN"
TERHUX_REPO_DIR="$PHONE" TERHUX_STATE_DIR="$STATE" bash "$ROOT_DIR/terhux-sync.sh" >/dev/null

grep -q 'owner update while phone was offline' "$PHONE/README.test" || fail 'remote code/docs update was not fetched'
[ -f "$STATE/results/issue-101.result" ] || fail 'local issue result did not survive the update'
[ "$(git -C "$PHONE" config --get-all branch.main.merge | wc -l)" -eq 2 ] || fail 'helper unexpectedly altered multiple-merge-ref configuration'
[ -z "$(git -C "$PHONE" status --porcelain)" ] || fail 'update left the code checkout dirty'
if git --git-dir="$ORIGIN" ls-tree -r --name-only main | grep -q '^results/issue-101.result$'; then
  fail 'job result was pushed to the code repository'
fi
if grep -Eq '^[[:space:]]*git[[:space:]]+pull([[:space:]]|$)' "$ROOT_DIR/terhux-sync.sh"; then
  fail 'update helper still executes git pull'
fi

echo 'PASS: issue state stays local, offline state survives, and explicit fetch/ff-only updates bypass git-pull multi-ref failures.'
