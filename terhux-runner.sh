#!/data/data/com.termux/files/usr/bin/bash

# Stop if a command fails unexpectedly
set -u

# Terhux repository
REPO_DIR="$HOME/terhux/repo"

# GitHub command queue
COMMAND_DIR="$REPO_DIR/commands"

# GitHub results folder
RESULT_DIR="$REPO_DIR/results"

# Make sure required folders exist
mkdir -p "$COMMAND_DIR" "$RESULT_DIR"

echo "=========================================="
echo "TERHUX COMMAND RUNNER"
echo "=========================================="
echo "Watching GitHub command queue..."
echo ""

# Check for a command file
COMMAND_FILE=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | head -n 1)

# Nothing to execute
if [ -z "$COMMAND_FILE" ]; then
    echo "No command found."
    exit 0
fi

# Read the command
COMMAND=$(cat "$COMMAND_FILE")

echo "Command received:"
echo "$COMMAND"
echo ""

# Generate a result filename
RESULT_FILE="$RESULT_DIR/$(basename "$COMMAND_FILE" .cmd).result"

# ==========================================
# SAFETY ALLOWLIST
# ==========================================

case "$COMMAND" in

    "pwd")
        OUTPUT=$(pwd 2>&1)
        ;;

    "whoami")
        OUTPUT=$(whoami 2>&1)
        ;;

    "date")
        OUTPUT=$(date 2>&1)
        ;;

    "termux-version")
        OUTPUT=$(termux-info 2>&1)
        ;;

    "git-version")
        OUTPUT=$(git --version 2>&1)
        ;;

    *)
        OUTPUT="BLOCKED: Command is not on the Terhux safety allowlist."
        ;;

esac

# Save result
{
    echo "Terhux execution result"
    echo "======================="
    echo "Command: $COMMAND"
    echo "Time: $(date)"
    echo ""
    echo "$OUTPUT"
} > "$RESULT_FILE"

# Remove processed command
rm -f "$COMMAND_FILE"

# Push result to GitHub
cd "$REPO_DIR"

git add results/
git commit -m "Terhux: command result" >/dev/null 2>&1 || true
git push >/dev/null 2>&1 || true

echo ""
echo "✅ Command processed."
echo "Result: $RESULT_FILE"
