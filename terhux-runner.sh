#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"

echo "=========================================="
echo "TERHUX COMMAND RUNNER"
echo "=========================================="

# Find the oldest pending command file.
COMMAND_FILE=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | sort | head -n 1)

if [ -z "$COMMAND_FILE" ]; then
    echo "No command found."
    exit 0
fi

COMMAND_ID=$(basename "$COMMAND_FILE" .cmd)
RAW_COMMAND=$(cat "$COMMAND_FILE")

# Structured commands use:
# ACTION=<allowlisted action>
# APPROVED=true
# Plain commands remain supported for the original five safe actions.
ACTION=""
APPROVED="false"

if printf '%s\n' "$RAW_COMMAND" | grep -q '^ACTION='; then
    ACTION=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^ACTION=//p' | head -n 1)
    APPROVED=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^APPROVED=//p' | head -n 1)
else
    ACTION="$RAW_COMMAND"
    case "$ACTION" in
        pwd|whoami|date|termux-version|git-version)
            APPROVED="true"
            ;;
    esac
fi

echo ""
echo "Command ID: $COMMAND_ID"
echo "Action: $ACTION"
echo "Approved: $APPROVED"

STATUS="SUCCESS"
EXIT_CODE=0
STDOUT=""
STDERR=""

# Safety allowlist: no arbitrary shell execution.
if [ "$APPROVED" != "true" ]; then
    STATUS="BLOCKED"
    STDERR="Approval required. Set APPROVED=true."
else
    case "$ACTION" in
        pwd)
            STDOUT=$(pwd)
            ;;
        whoami)
            STDOUT=$(whoami)
            ;;
        date)
            STDOUT=$(date)
            ;;
        termux-version)
            STDOUT=$(termux-info 2>&1 | head -20)
            ;;
        git-version)
            STDOUT=$(git --version)
            ;;
        node-version)
            STDOUT=$(node --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        npm-version)
            STDOUT=$(npm --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        git-status)
            STDOUT=$(git -C "$REPO_DIR" status --short --branch 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        *)
            STATUS="BLOCKED"
            STDERR="Action is not on the Terhux safety allowlist."
            ;;
    esac
fi

RESULT_FILE="$RESULT_DIR/$COMMAND_ID.result"

{
    echo "TERHUX RESULT"
    echo "=============="
    echo "ID: $COMMAND_ID"
    echo "ACTION: $ACTION"
    echo "APPROVED: $APPROVED"
    echo "STATUS: $STATUS"
    echo "EXIT_CODE: $EXIT_CODE"
    echo "TIME: $(date)"
    echo ""
    echo "STDOUT:"
    echo "$STDOUT"
    echo ""
    echo "STDERR:"
    echo "$STDERR"
} > "$RESULT_FILE"

# Remove the processed command.
rm -f "$COMMAND_FILE"

# Send the result back to GitHub.
git -C "$REPO_DIR" add commands results
git -C "$REPO_DIR" commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
git -C "$REPO_DIR" push >/dev/null 2>&1 || true

echo ""
echo "Command processed."
echo "Result: $RESULT_FILE"
