#!/data/data/com.termux/files/usr/bin/bash
set -u

# Called by the runner as: terhux-exec.sh <working-directory> <program> [args...]
[ "$#" -ge 2 ] || { echo 'usage: terhux-exec.sh <working-directory> <program> [args...]' >&2; exit 125; }
WORKDIR="$1"
shift
SECONDS_LIMIT="${TERHUX_ACTION_TIMEOUT_SECONDS:-600}"
OUTPUT_BLOCK_LIMIT="${TERHUX_OUTPUT_LIMIT_BLOCKS:-256}"

case "$SECONDS_LIMIT" in ''|*[!0-9]*) SECONDS_LIMIT=600;; esac
[ "$SECONDS_LIMIT" -gt 0 ] || SECONDS_LIMIT=600
[ "$SECONDS_LIMIT" -le 1800 ] || SECONDS_LIMIT=1800
case "$OUTPUT_BLOCK_LIMIT" in ''|*[!0-9]*) OUTPUT_BLOCK_LIMIT=256;; esac
[ "$OUTPUT_BLOCK_LIMIT" -gt 0 ] || OUTPUT_BLOCK_LIMIT=256
[ "$OUTPUT_BLOCK_LIMIT" -le 512 ] || OUTPUT_BLOCK_LIMIT=512

command -v timeout >/dev/null 2>&1 || { echo 'Required timeout utility is missing; install Termux coreutils.' >&2; exit 125; }
OUT_FILE=$(mktemp "${TMPDIR:-/tmp}/terhux-action.XXXXXX") || { echo 'Cannot create action output file.' >&2; exit 125; }

(
  cd "$WORKDIR" || exit 126
  # Bound the captured output file (256 blocks by default) as well as wall time.
  ulimit -f "$OUTPUT_BLOCK_LIMIT" 2>/dev/null || exit 125
  exec timeout --signal=TERM --kill-after=5s "${SECONDS_LIMIT}s" "$@"
) >"$OUT_FILE" 2>&1
RC=$?
cat "$OUT_FILE"
rm -f "$OUT_FILE"

# Bash/Linux encode SIGXFSZ (output cap) as 128 + 25 = 153.
[ "$RC" -eq 153 ] && exit 122
exit "$RC"
