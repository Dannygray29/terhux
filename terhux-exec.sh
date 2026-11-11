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
command -v head >/dev/null 2>&1 || { echo 'Required head utility is missing.' >&2; exit 125; }
OUT_FILE=$(mktemp "${TMPDIR:-$PREFIX/tmp}/terhux-action.XXXXXX") || { echo 'Cannot create action output file.' >&2; exit 125; }
CAP_BYTES=$((OUTPUT_BLOCK_LIMIT * 512))
TRIM_FILE="$OUT_FILE.trim"
trap 'rm -f "$OUT_FILE" "$TRIM_FILE"' EXIT

# Do not apply ulimit -f to the command: that also blocks package managers
# and other legitimate child processes from writing files. Capture one extra
# byte so output overflow is distinguishable from a command that exits cleanly
# after producing exactly CAP_BYTES.
set +e
(
  cd "$WORKDIR" || exit 126
  exec timeout --signal=TERM --kill-after=5s "${SECONDS_LIMIT}s" "$@"
) 2>&1 | head -c "$((CAP_BYTES + 1))" >"$OUT_FILE"
PIPE_RC=${PIPESTATUS[0]}
OUTPUT_BYTES=$(wc -c <"$OUT_FILE")
if [ "$OUTPUT_BYTES" -gt "$CAP_BYTES" ]; then
  head -c "$CAP_BYTES" "$OUT_FILE" >"$TRIM_FILE"
  mv -f "$TRIM_FILE" "$OUT_FILE"
  PIPE_RC=122
fi
cat "$OUT_FILE"
rm -f "$OUT_FILE" "$TRIM_FILE"
trap - EXIT

# Exit 122 specifically means captured output exceeded the configured cap.
exit "$PIPE_RC"
