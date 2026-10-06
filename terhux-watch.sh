#!/data/data/com.termux/files/usr/bin/bash

# Terhux repository
REPO_DIR="$HOME/terhux/repo"
INTERVAL="${TERHUX_INTERVAL:-10}"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
MAX_WORKERS="${TERHUX_WORKERS:-3}"
AUTO_RECOVER="${TERHUX_AI_AUTO_RECOVER:-1}"

echo "=========================================="
echo "TERHUX MULTI-WORKER WATCHER"
echo "=========================================="
echo "Watching GitHub every $INTERVAL seconds..."
echo "Maximum concurrent workers: $MAX_WORKERS"
echo "AI automatic recovery: $AUTO_RECOVER"
echo "Press Ctrl+C to stop."

worker_count() {
    pgrep -f "$REPO_DIR/terhux-worker.sh" | wc -l
}

ai_recovery_count() {
    pgrep -f "terhux-ai-agent.js recover" | wc -l
}

while true; do
    cd "$REPO_DIR" || exit 1

    git pull --quiet --rebase 2>/dev/null || true

    # Keep the watcher's own scripts current from GitHub.
    chmod +x "$REPO_DIR"/terhux-*.sh 2>/dev/null || true

    if [ "$AUTO_RECOVER" = "1" ] && [ "$(ai_recovery_count)" -eq 0 ]; then
        nohup node "$REPO_DIR/terhux-ai-agent.js" recover >/dev/null 2>&1 &
    fi

    RUNNING=$(worker_count)
    while [ "$RUNNING" -lt "$MAX_WORKERS" ]; do
        if ! find "$REPO_DIR/commands" -maxdepth 1 -type f -name "*.cmd" | grep -q .; then
            break
        fi
        nohup "$REPO_DIR/terhux-worker.sh" >/dev/null 2>&1 &
        sleep 0.2
        RUNNING=$(worker_count)
    done

    sleep "$INTERVAL"
done
