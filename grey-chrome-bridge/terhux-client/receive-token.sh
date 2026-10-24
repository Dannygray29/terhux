#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
TOKEN="${1:-}"
if [[ ! "$TOKEN" =~ ^[A-Za-z0-9_-]{40,60}$ ]]; then
  echo "GREY Chrome Bridge: invalid token received; no changes made." >&2
  exit 2
fi
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/grey-chrome-bridge"
umask 077
mkdir -p "$CONFIG_DIR"
printf '%s' "$TOKEN" > "$CONFIG_DIR/token"
chmod 600 "$CONFIG_DIR/token"
unset TOKEN
echo "GREY Chrome Bridge token stored securely. Now run: bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh status"
