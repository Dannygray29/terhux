#!/data/data/com.termux/files/usr/bin/bash
set -u
echo "TERHUX_DIRECT:"
pgrep -af "[t]erhux-direct.py" || echo "stopped"
echo "TERHUX_RELAY:"
pgrep -af "[t]erhux-relay.py" || echo "stopped"
echo "RELAY_CONFIG:"
if [ -n "${TERHUX_RELAY_URL:-}" ] && [ -n "${TERHUX_RELAY_TOKEN:-}" ]; then
  echo "configured"
else
  echo "not-configured"
fi
