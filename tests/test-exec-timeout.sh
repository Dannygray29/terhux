#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
command -v timeout >/dev/null || { echo 'SKIP: timeout is not installed'; exit 0; }

set +e
TERHUX_ACTION_TIMEOUT_SECONDS=1 bash "$ROOT_DIR/terhux-exec.sh" "$TMP_DIR" bash -c 'while :; do :; done' >"$TMP_DIR/timeout.log" 2>&1
TIMEOUT_RC=$?
set -e
case "$TIMEOUT_RC" in 124|137) ;; *) echo "FAIL: expected timeout exit, got $TIMEOUT_RC" >&2; exit 1;; esac

set +e
TERHUX_ACTION_TIMEOUT_SECONDS=10 TERHUX_OUTPUT_LIMIT_BLOCKS=2 \
  bash "$ROOT_DIR/terhux-exec.sh" "$TMP_DIR" yes output >"$TMP_DIR/output-cap.log" 2>&1
OUTPUT_RC=$?
set -e
OUTPUT_BYTES=$(wc -c <"$TMP_DIR/output-cap.log")
[ "$OUTPUT_RC" -eq 122 ] || { echo "FAIL: expected output-limit exit 122, got $OUTPUT_RC" >&2; exit 1; }
[ "$OUTPUT_BYTES" -le 8192 ] || { echo "FAIL: output capture was too large: $OUTPUT_BYTES bytes" >&2; exit 1; }
echo 'PASS: wall time is enforced and noisy output capture remains bounded.'
