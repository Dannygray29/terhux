#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ORIGIN="$TMP_DIR/origin.git"
PHONE="$TMP_DIR/phone"
AGENT="$TMP_DIR/agent"

fail() { echo "FAIL: $*" >&2; exit 1; }

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git clone "$ORIGIN" "$PHONE" >/dev/null 2>&1
cd "$PHONE"
git config user.name 'Terhux Test'
git config user.email 'terhux-test@example.invalid'
mkdir -p commands results logs
echo 'test repo' > README.test
git add .
git commit -m 'test base' >/dev/null
git push -u origin main >/dev/null 2>&1

# Simulate an agent publishing a request to the GitHub queue.
git clone "$ORIGIN" "$AGENT" >/dev/null 2>&1
git -C "$AGENT" config user.name 'Agent Test'
git -C "$AGENT" config user.email 'agent-test@example.invalid'
mkdir -p "$AGENT/commands"
printf 'ACTION=terhux-runner-version\nAPPROVED=true\n' > "$AGENT/commands/offline-check.cmd"
git -C "$AGENT" add commands/offline-check.cmd
git -C "$AGENT" commit -m 'queue request' >/dev/null
git -C "$AGENT" push origin main >/dev/null 2>&1

TERHUX_REPO_DIR="$PHONE" TERHUX_SYNC_RETRIES=1 TERHUX_SYNC_BASE_DELAY=0 \
  bash "$ROOT_DIR/terhux-sync.sh"
[ -f "$PHONE/commands/offline-check.cmd" ] || fail 'phone did not fetch queued request'

# Simulate successful local execution while the phone cannot reach GitHub.
printf 'TERHUX_RESULT_V1\nID=offline-check\nSTATUS=SUCCESS\nEXIT_CODE=0\n' > "$PHONE/results/offline-check.result"
rm "$PHONE/commands/offline-check.cmd"
git -C "$PHONE" remote set-url origin "$TMP_DIR/unavailable.git"
if TERHUX_REPO_DIR="$PHONE" TERHUX_SYNC_RETRIES=2 TERHUX_SYNC_BASE_DELAY=0 \
  bash "$ROOT_DIR/terhux-sync.sh"; then
  fail 'sync unexpectedly succeeded with an unavailable remote'
fi
[ -f "$PHONE/results/offline-check.result" ] || fail 'result was lost during outage'
[ ! -e "$PHONE/commands/offline-check.cmd" ] || fail 'consumed command was restored/lost its local acknowledgement'

# A second agent request arrives remotely while the phone is offline.
printf 'ACTION=terhux-runner-version\nAPPROVED=true\n' > "$AGENT/commands/while-offline.cmd"
git -C "$AGENT" add commands/while-offline.cmd
git -C "$AGENT" commit -m 'queue request during outage' >/dev/null
git -C "$AGENT" push origin main >/dev/null 2>&1

# Reconnect the phone; its local result must rebase onto the new request and push.
git -C "$PHONE" remote set-url origin "$ORIGIN"
TERHUX_REPO_DIR="$PHONE" TERHUX_SYNC_RETRIES=3 TERHUX_SYNC_BASE_DELAY=0 \
  bash "$ROOT_DIR/terhux-sync.sh"

VERIFY="$TMP_DIR/verify"
git clone "$ORIGIN" "$VERIFY" >/dev/null 2>&1
[ -f "$VERIFY/results/offline-check.result" ] || fail 'result was not published after reconnect'
[ ! -e "$VERIFY/commands/offline-check.cmd" ] || fail 'completed request was not acknowledged remotely'
[ -f "$VERIFY/commands/while-offline.cmd" ] || fail 'new remote request was lost during recovery'
echo 'PASS: queued requests survive offline periods; local results retry and preserve concurrent incoming requests.'
