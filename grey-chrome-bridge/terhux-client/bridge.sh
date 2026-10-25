#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE_URL="http://127.0.0.1:8765"
TOKEN_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/grey-chrome-bridge/token"
if [ ! -r "$TOKEN_FILE" ]; then
  echo "No private bridge token found. Run: bash grey-chrome-bridge/terhux-client/setup-token.sh" >&2
  exit 2
fi
TOKEN="$(cat "$TOKEN_FILE")"
if [ "${#TOKEN}" -lt 40 ]; then echo "Stored token is invalid; re-run setup-token.sh." >&2; exit 2; fi
request() {
  curl --silent --show-error --fail --max-time 4 -H "X-Grey-Token: $TOKEN" "$@"
}
cmd="${1:-help}"
case "$cmd" in
  status)
    request "$BASE_URL/health"
    ;;
  screen)
    request "$BASE_URL/windows" | python -c 'import json,re,sys; d=json.load(sys.stdin); print("Foreground package:", d.get("activePackage","unknown")); print("Visible labels:"); [print(" -", re.sub(r"[^@\s]+@[^@\s]+\.[^@\s]+", "[redacted email]", str(x.get("text","")))) for x in d.get("visibleText",[])]'
    ;;
  tap)
    [ "$#" -eq 3 ] || { echo "Usage: bridge.sh tap X Y" >&2; exit 2; }
    [[ "$2" =~ ^[0-9]{1,5}$ && "$3" =~ ^[0-9]{1,5}$ ]] || { echo "Coordinates must be non-negative pixel integers." >&2; exit 2; }
    printf 'Send one tap at screen coordinate (%s,%s)? Type YES to continue: ' "$2" "$3"
    IFS= read -r answer
    [ "$answer" = "YES" ] || { echo "Cancelled."; exit 0; }
    request -X POST "$BASE_URL/tap?x=$2&y=$3"
    ;;
  scroll)
    [ "$#" -eq 2 ] && { [ "$2" = up ] || [ "$2" = down ]; } || { echo "Usage: bridge.sh scroll up|down" >&2; exit 2; }
    printf 'Scroll the current app %s? Type YES to continue: ' "$2"
    IFS= read -r answer
    [ "$answer" = "YES" ] || { echo "Cancelled."; exit 0; }
    request -X POST "$BASE_URL/scroll?direction=$2"
    ;;
  help|*)
    echo "GREY Chrome Bridge CLI (opt-in, visible UI only)"
    echo "  $0 status       Check service"
    echo "  $0 screen       Read visible non-editable UI labels"
    echo "  $0 tap X Y      Ask confirmation, then send one tap"
    echo "  $0 scroll up|down  Ask confirmation, then scroll"
    echo "Token stays in private Termux config; never put it in GitHub or chat."
    [ "$cmd" = help ] || exit 2
    ;;
esac
