#!/data/data/com.termux/files/usr/bin/bash

# Terhux repository
REPO_DIR="$HOME/terhux/repo"

# Check GitHub every 10 seconds
INTERVAL=10

echo "=========================================="
echo "TERHUX WATCHER"
echo "=========================================="
echo "Watching GitHub every $INTERVAL seconds..."
echo "Press Ctrl+C to stop."

while true; do

    # Enter repository
    cd "$REPO_DIR" || exit 1

    # Download the latest commands/results from GitHub
    git pull --quiet --rebase 2>/dev/null || true

    # Run the command runner
    ./terhux-runner.sh

    # Wait before checking again
    sleep "$INTERVAL"

done
