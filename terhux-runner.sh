#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"

echo "=========================================="
echo "TERHUX COMMAND RUNNER"
echo "=========================================="

COMMAND_FILE=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | sort | head -n 1)

if [ -z "$COMMAND_FILE" ]; then
    echo "No command found."
    exit 0
fi

COMMAND_ID=$(basename "$COMMAND_FILE" .cmd)
RAW_COMMAND=$(cat "$COMMAND_FILE")

# Structured protocol:
# ACTION=<allowlisted action>
# PROJECT=<registered project, when required>
# APPROVED=true
ACTION=""
PROJECT=""
APPROVED="false"

if printf '%s\n' "$RAW_COMMAND" | grep -q '^ACTION='; then
    ACTION=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^ACTION=//p' | head -n 1)
    PROJECT=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^PROJECT=//p' | head -n 1)
    APPROVED=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^APPROVED=//p' | head -n 1)
else
    ACTION="$RAW_COMMAND"
    case "$ACTION" in
        pwd|whoami|date|termux-version|git-version)
            APPROVED="true"
            ;;
    esac
fi

STATUS="SUCCESS"
EXIT_CODE=0
STDOUT=""
STDERR=""
PROJECT_DIR=""

# Registered project map. Only these directories can be targeted.
case "$PROJECT" in
    "")
        ;;
    terhux)
        PROJECT_DIR="$REPO_DIR"
        ;;
    void)
        PROJECT_DIR="$HOME/void"
        ;;
    *)
        STATUS="BLOCKED"
        STDERR="Unknown project. Project is not registered with Terhux."
        ;;
esac

# Safety gate: approval plus explicit action allowlist.
if [ "$STATUS" = "SUCCESS" ] && [ "$APPROVED" != "true" ]; then
    STATUS="BLOCKED"
    STDERR="Approval required. Set APPROVED=true."
fi

if [ "$STATUS" = "SUCCESS" ]; then
    case "$ACTION" in
        pwd) STDOUT=$(pwd) ;;
        whoami) STDOUT=$(whoami) ;;
        date) STDOUT=$(date) ;;
        termux-version) STDOUT=$(termux-info 2>&1 | head -20) ;;
        git-version) STDOUT=$(git --version) ;;
        node-version)
            STDOUT=$(node --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        npm-version)
            STDOUT=$(npm --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        project-list)
            STDOUT=$(find "$HOME" -maxdepth 2 -type d -name .git -print 2>/dev/null | sed 's#/.git$##' | sort) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        git-status|git-branch|npm-test|npm-build)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"
                STDERR="This action requires PROJECT=<registered project>."
            elif [ ! -d "$PROJECT_DIR" ]; then
                STATUS="ERROR"
                STDERR="Registered project directory does not exist: $PROJECT_DIR"
                EXIT_CODE=1
            elif [ "$ACTION" = "git-status" ]; then
                STDOUT=$(git -C "$PROJECT_DIR" status --short --branch 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            elif [ "$ACTION" = "git-branch" ]; then
                STDOUT=$(git -C "$PROJECT_DIR" branch --show-current 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            elif [ "$ACTION" = "npm-test" ]; then
                if [ -f "$PROJECT_DIR/package.json" ]; then
                    STDOUT=$(cd "$PROJECT_DIR" && npm test 2>&1)
                    EXIT_CODE=$?
                    [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                else
                    STATUS="BLOCKED"
                    STDERR="No package.json in the selected project."
                fi
            elif [ "$ACTION" = "npm-build" ]; then
                if [ -f "$PROJECT_DIR/package.json" ]; then
                    STDOUT=$(cd "$PROJECT_DIR" && npm run build 2>&1)
                    EXIT_CODE=$?
                    [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                else
                    STATUS="BLOCKED"
                    STDERR="No package.json in the selected project."
                fi
            fi
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
    echo "PROJECT: $PROJECT"
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

rm -f "$COMMAND_FILE"

git -C "$REPO_DIR" add commands results
git -C "$REPO_DIR" commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
git -C "$REPO_DIR" push >/dev/null 2>&1 || true

echo "Command processed: $COMMAND_ID"
