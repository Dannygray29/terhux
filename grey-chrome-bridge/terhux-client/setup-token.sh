#!/data/data/com.termux/files/usr/bin/bash
set -eu
umask 077
dir="${XDG_CONFIG_HOME:-$HOME/.config}/grey-chrome-bridge"
mkdir -p "$dir"
printf '%s' 'Paste the local token shown in GREY Chrome Bridge (input hidden): '
IFS= read -r -s token
printf '\n'
if [ "${#token}" -lt 40 ]; then
  echo "Token looks too short; nothing saved." >&2
  exit 1
fi
printf '%s' "$token" > "$dir/token"
chmod 600 "$dir/token"
unset token
echo "Token saved privately to $dir/token (permissions 600). It was not printed or logged."
echo "Next: run ./grey-chrome-bridge/terhux-client/bridge.sh status"
