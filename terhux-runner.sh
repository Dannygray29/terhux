#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"

echo "=========================================="
echo "TERHUX COMMAND RUNNER"
echo "=========================================="

# Find the oldest pending command
COMMAND_FILE=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | sort | head -n 1)

# Nothing to process
if [ -z "$COMMAND_FILE" ]; then
    echo "No command found."
    exit 0
fi

COMMAND_ID=$(basename "$COMMAND_FILE" .cmd)
COMMAND=$(cat "$COMMAND_FILE")

echo ""
echo "Command ID: $COMMAND_ID"
echo "Command: $COMMAND"

# Safety allowlist
case "$COMMAND" in
    pwd)
        RESULT=$(pwd)
        ;;
    whoami)
        RESULT=$(whoami)
        ;;
    date)
        RESULT=$(date)
        ;;
    termux-version)
        RESULT=$(termux-info 2>&1 | head -20)
        ;;
    git-version)
        RESULT=$(git --version)
        ;;
    *)
        RESULT="BLOCKED: Command is not on the Terhux safety allowlist."
        ;;
esac

# Save result
RESULT_FILE="$RESULT_DIR/$COMMAND_ID.result"

{
    echo "TERHUX RESULT"
    echo "=============="
    echo "ID: $COMMAND_ID"
    echo "COMMAND: $COMMAND"
    echo "TIME: $(date)"
    echo ""
    echo "$RESULT"
} > "$RESULT_FILE"

# Remove processed command
rm -f "$COMMAND_FILE"

# Send result back to GitHub
git add commands results
git commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
git push >/dev/null 2>&1 || true

echo ""
echo "Command processed."
echo "Result: $RESULT_FILE"
