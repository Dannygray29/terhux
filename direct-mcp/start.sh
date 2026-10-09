#!/data/data/com.termux/files/usr/bin/bash
set -eu
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
APP_DIR="$REPO_DIR/direct-mcp"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/terhux/direct-mcp"
CONFIG_DIR="$HOME/.config/terhux"
ENV_FILE="$CONFIG_DIR/direct-mcp.env"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$HOME/.termux/boot"
chmod 700 "$CONFIG_DIR" "$STATE_DIR" "$LOG_DIR"

if [ ! -f "$ENV_FILE" ]; then
  if command -v openssl >/dev/null 2>&1; then
    TOKEN="$(openssl rand -hex 32)"
  elif command -v python >/dev/null 2>&1; then
    TOKEN="$(python -c 'import secrets; print(secrets.token_hex(32))')"
  elif command -v python3 >/dev/null 2>&1; then
    TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  else
    echo "Need openssl or Python to generate the local access token." >&2
    exit 1
  fi
  printf 'export TERHUX_MCP_TOKEN=%q\n' "$TOKEN" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Created private MCP token at $ENV_FILE (never share or commit it)."
fi

# Stop duplicate local servers before starting a fresh one.
if pgrep -f "$APP_DIR/server.mjs" >/dev/null 2>&1; then
  echo "Direct MCP server is already running."
else
  nohup bash -lc 'source "$HOME/.config/terhux/direct-mcp.env"; exec node "$HOME/terhux/repo/direct-mcp/server.mjs"' >>"$LOG_DIR/server.log" 2>&1 </dev/null &
  sleep 2
fi

# A named Cloudflare Tunnel is optional but recommended for stable remote access.
# Its config and credentials must be created privately on this phone first.
if command -v cloudflared >/dev/null 2>&1 && [ -f "$HOME/.cloudflared/config.yml" ]; then
  if ! pgrep -f 'cloudflared tunnel run' >/dev/null 2>&1; then
    nohup cloudflared tunnel run >>"$LOG_DIR/tunnel.log" 2>&1 </dev/null &
  fi
fi

# Install a Termux:Boot entry so the local MCP endpoint resumes after reboot.
cat > "$HOME/.termux/boot/start-terhux-direct-mcp" <<'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
sleep 8
bash "$HOME/terhux/repo/direct-mcp/start.sh" >>"$HOME/.local/state/terhux/direct-mcp/logs/boot.log" 2>&1
BOOT
chmod 700 "$HOME/.termux/boot/start-terhux-direct-mcp"

if curl -fsS http://127.0.0.1:8787/health >/dev/null 2>&1; then
  echo "Direct MCP server is responding locally at http://127.0.0.1:8787/mcp"
else
  echo "Server did not pass its local health check. Inspect $LOG_DIR/server.log" >&2
  exit 1
fi
if [ -f "$HOME/.cloudflared/config.yml" ]; then
  echo "Named tunnel startup requested; inspect $LOG_DIR/tunnel.log for tunnel status."
else
  echo "Remote access is not configured yet: set up a named authenticated tunnel to http://127.0.0.1:8787."
fi
echo "Boot launcher installed. Termux:Boot must be installed/enabled and Android must allow background execution."
