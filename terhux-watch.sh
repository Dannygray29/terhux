#!/data/data/com.termux/files/usr/bin/bash
REPO_DIR="$HOME/terhux/repo"
INTERVAL="${TERHUX_INTERVAL:-8}"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
MAX_WORKERS="${TERHUX_WORKERS:-3}"
AUTO_RECOVER="${TERHUX_AI_AUTO_RECOVER:-1}"
chmod +x "$REPO_DIR"/terhux-*.sh 2>/dev/null || true
worker_count() { pgrep -f "$REPO_DIR/terhux-worker.sh" | wc -l; }
ai_recovery_count() { pgrep -f "terhux-ai-agent.js recover" | wc -l; }
echo "TERHUX WATCHER ONLINE: interval=$INTERVAL workers=$MAX_WORKERS"
while true; do
  cd "$REPO_DIR" || exit 1
  git pull --quiet --rebase 2>/dev/null || true
  chmod +x "$REPO_DIR"/terhux-*.sh 2>/dev/null || true
  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true
  if [ "$AUTO_RECOVER" = "1" ] && [ "$(ai_recovery_count)" -eq 0 ] && [ -f "$REPO_DIR/terhux-ai-agent.js" ]; then
    nohup node "$REPO_DIR/terhux-ai-agent.js" recover >>"$LOG_DIR/ai-recovery.log" 2>&1 &
  fi
  RUNNING=$(worker_count)
  while [ "$RUNNING" -lt "$MAX_WORKERS" ]; do
    find "$REPO_DIR/commands" -maxdepth 1 -type f -name "*.cmd" | grep -q . || break
    nohup "$REPO_DIR/terhux-worker.sh" >>"$LOG_DIR/worker.log" 2>&1 &
    sleep 0.3
    RUNNING=$(worker_count)
  done
  sleep "$INTERVAL"
done
