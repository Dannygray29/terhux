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

# Protocol: ACTION=..., PROJECT=..., PATH=..., CONTENT=..., APPROVED=true
ACTION=""
PROJECT=""
REL_PATH=""
CONTENT=""
APPROVED="false"

ACTION=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^ACTION=//p' | head -n 1)
PROJECT=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^PROJECT=//p' | head -n 1)
REL_PATH=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^PATH=//p' | head -n 1)
APPROVED=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^APPROVED=//p' | head -n 1)

# Backward compatibility for the original simple commands.
if [ -z "$ACTION" ]; then
    ACTION="$RAW_COMMAND"
    case "$ACTION" in
        pwd|whoami|date|termux-version|git-version) APPROVED="true" ;;
    esac
fi

STATUS="SUCCESS"
EXIT_CODE=0
STDOUT=""
STDERR=""
PROJECT_DIR=""

# Only registered project roots are allowed.
case "$PROJECT" in
    "") ;;
    terhux) PROJECT_DIR="$REPO_DIR" ;;
    void) PROJECT_DIR="$HOME/void" ;;
    *) STATUS="BLOCKED"; STDERR="Unknown project. Project is not registered with Terhux." ;;
esac

# File paths must be relative and cannot escape the registered project.
SAFE_PATH="false"
if [ -n "$REL_PATH" ] && [ -n "$PROJECT_DIR" ]; then
    case "$REL_PATH" in
        /*|../*|*/../*|*/..|..)
            SAFE_PATH="false"
            ;;
        *)
            SAFE_PATH="true"
            TARGET="$PROJECT_DIR/$REL_PATH"
            ;;
    esac
fi

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
            STDOUT=$(node --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; } ;;
        npm-version)
            STDOUT=$(npm --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; } ;;
        project-list)
            STDOUT=$(find "$HOME" -maxdepth 2 -type d -name .git -print 2>/dev/null | sed 's#/.git$##' | sort) || { EXIT_CODE=$?; STATUS="ERROR"; } ;;
        git-status|git-branch|npm-test|npm-build)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="This action requires PROJECT=<registered project>."
            elif [ ! -d "$PROJECT_DIR" ]; then
                STATUS="ERROR"; EXIT_CODE=1; STDERR="Registered project directory does not exist: $PROJECT_DIR"
            elif [ "$ACTION" = "git-status" ]; then
                STDOUT=$(git -C "$PROJECT_DIR" status --short --branch 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            elif [ "$ACTION" = "git-branch" ]; then
                STDOUT=$(git -C "$PROJECT_DIR" branch --show-current 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            elif [ "$ACTION" = "npm-test" ]; then
                if [ -f "$PROJECT_DIR/package.json" ]; then
                    STDOUT=$(cd "$PROJECT_DIR" && npm test 2>&1); EXIT_CODE=$?; [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                else STATUS="BLOCKED"; STDERR="No package.json in the selected project."; fi
            elif [ "$ACTION" = "npm-build" ]; then
                if [ -f "$PROJECT_DIR/package.json" ]; then
                    STDOUT=$(cd "$PROJECT_DIR" && npm run build 2>&1); EXIT_CODE=$?; [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                else STATUS="BLOCKED"; STDERR="No package.json in the selected project."; fi
            fi
            ;;
        file-list)
            if [ "$SAFE_PATH" != "true" ]; then
                STATUS="BLOCKED"; STDERR="A safe relative PATH is required."
            elif [ ! -d "$TARGET" ]; then
                STATUS="ERROR"; EXIT_CODE=1; STDERR="Directory does not exist."
            else
                STDOUT=$(find "$TARGET" -maxdepth 2 -type f -print | sort) || { EXIT_CODE=$?; STATUS="ERROR"; }
            fi
            ;;
        file-read)
            if [ "$SAFE_PATH" != "true" ]; then
                STATUS="BLOCKED"; STDERR="A safe relative PATH is required."
            elif [ ! -f "$TARGET" ]; then
                STATUS="ERROR"; EXIT_CODE=1; STDERR="File does not exist."
            else
                STDOUT=$(cat "$TARGET") || { EXIT_CODE=$?; STATUS="ERROR"; }
            fi
            ;;
        file-write)
            if [ "$SAFE_PATH" != "true" ]; then
                STATUS="BLOCKED"; STDERR="A safe relative PATH is required."
            elif [ -z "$CONTENT" ]; then
                STATUS="BLOCKED"; STDERR="CONTENT is required."
            else
                mkdir -p "$(dirname "$TARGET")"
                printf '%s\n' "$CONTENT" > "$TARGET"
                EXIT_CODE=$?
                [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                STDOUT="Wrote $REL_PATH"
            fi
            ;;
        git-diff)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT is required."
            else
                STDOUT=$(git -C "$PROJECT_DIR" diff -- 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; }
            fi
            ;;
        git-add)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT is required."
            elif [ -z "$REL_PATH" ]; then
                STATUS="BLOCKED"; STDERR="PATH is required for git-add."
            elif [ "$SAFE_PATH" != "true" ]; then
                STATUS="BLOCKED"; STDERR="A safe relative PATH is required."
            else
                git -C "$PROJECT_DIR" add -- "$REL_PATH"
                EXIT_CODE=$?
                [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                STDOUT="Staged $REL_PATH"
            fi
            ;;
        git-commit)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT is required."
            elif [ -z "$CONTENT" ]; then
                STATUS="BLOCKED"; STDERR="CONTENT is required as the commit message."
            else
                git -C "$PROJECT_DIR" commit -m "$CONTENT" 2>&1
                EXIT_CODE=$?
                [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                STDOUT="Commit operation completed."
            fi
            ;;
        git-push)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT is required."
            else
                git -C "$PROJECT_DIR" push 2>&1
                EXIT_CODE=$?
                [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                STDOUT="Push operation completed."
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
    echo "TERHUX_RESULT_V1"
    echo "ID=$COMMAND_ID"
    echo "ACTION=$ACTION"
    echo "PROJECT=$PROJECT"
    echo "PATH=$REL_PATH"
    echo "APPROVED=$APPROVED"
    echo "STATUS=$STATUS"
    echo "EXIT_CODE=$EXIT_CODE"
    echo "TIME=$(date +%s)"
    echo "---STDOUT---"
    echo "$STDOUT"
    echo "---END_STDOUT---"
    echo "---STDERR---"
    echo "$STDERR"
    echo "---END_STDERR---"
} > "$RESULT_FILE"

rm -f "$COMMAND_FILE"
git -C "$REPO_DIR" add commands results
git -C "$REPO_DIR" commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
git -C "$REPO_DIR" push >/dev/null 2>&1 || true
echo "Command processed: $COMMAND_ID"
