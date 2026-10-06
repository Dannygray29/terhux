#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"

echo "=========================================="
echo "TERHUX COMMAND RUNNER"
echo "=========================================="

COMMAND_FILE="${1:-}"
if [ -z "$COMMAND_FILE" ]; then
    mkdir -p "$COMMAND_DIR/.running"
    NEXT_COMMAND=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | sort | head -n 1)
    if [ -n "$NEXT_COMMAND" ]; then
        CLAIMED="$COMMAND_DIR/.running/$(basename "$NEXT_COMMAND")"
        if mv "$NEXT_COMMAND" "$CLAIMED" 2>/dev/null; then COMMAND_FILE="$CLAIMED"; fi
    fi
fi
if [ -z "$COMMAND_FILE" ] || [ ! -f "$COMMAND_FILE" ]; then
    echo "No command found."
    exit 0
fi

COMMAND_ID=$(basename "$COMMAND_FILE" .cmd)
RAW_COMMAND=$(cat "$COMMAND_FILE")

ACTION=""
PROJECT=""
REL_PATH=""
CONTENT=""
CONTENT_B64=""
APPROVED="false"

ACTION=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^ACTION=//p' | head -n 1)
PROJECT=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^PROJECT=//p' | head -n 1)
REL_PATH=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^PATH=//p' | head -n 1)
APPROVED=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^APPROVED=//p' | head -n 1)
CONTENT=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^CONTENT=//p' | head -n 1)
CONTENT_B64=$(printf '%s\n' "$RAW_COMMAND" | sed -n 's/^CONTENT_B64=//p' | head -n 1)

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

case "$PROJECT" in
    "") ;;
    *)
        REGISTRY="$REPO_DIR/projects.conf"
        if [ -f "$REGISTRY" ]; then
            REGISTRY_PATH=$(awk -F'|' -v project="$PROJECT" '$1 == project {print $2; exit}' "$REGISTRY")
            case "$REGISTRY_PATH" in
                /data/*|/storage/*|/sdcard/*)
                    PROJECT_DIR="$REGISTRY_PATH"
                    ;;
                "\$HOME"/*)
                    PROJECT_DIR="$HOME/${REGISTRY_PATH#\$HOME/}"
                    ;;
                "")
                    PROJECT_DIR=""
                    ;;
                *)
                    STATUS="BLOCKED"
                    STDERR="Invalid project registry path. Use an absolute path or \$HOME-relative path."
                    ;;
            esac
        fi
        if [ -z "$PROJECT_DIR" ] && [ "$STATUS" = "SUCCESS" ]; then
            STATUS="BLOCKED"
            STDERR="Unknown project. Register it in projects.conf before use."
        fi
        ;;
esac

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
        node-version) STDOUT=$(node --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; } ;;
        npm-version) STDOUT=$(npm --version 2>&1) || { EXIT_CODE=$?; STATUS="ERROR"; } ;;
        project-list)
            STDOUT=$(find "$HOME" -maxdepth 2 -type d -name .git -print 2>/dev/null | sed 's#/.git$##' | sort) || { EXIT_CODE=$?; STATUS="ERROR"; }
            ;;
        project-check)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT is required."
            elif [ ! -d "$PROJECT_DIR" ]; then
                STATUS="ERROR"; EXIT_CODE=1; STDERR="Registered project directory does not exist: $PROJECT_DIR"
            elif [ ! -f "$PROJECT_DIR/package.json" ]; then
                STATUS="BLOCKED"; STDERR="No package.json in the selected project."
            else
                TEST_OUTPUT=$(cd "$PROJECT_DIR" && npm test 2>&1)
                TEST_EXIT=$?
                BUILD_OUTPUT=""
                BUILD_EXIT=0
                if [ "$TEST_EXIT" -eq 0 ]; then
                    BUILD_OUTPUT=$(cd "$PROJECT_DIR" && npm run build 2>&1)
                    BUILD_EXIT=$?
                fi
                STDOUT="TEST_EXIT_CODE=$TEST_EXIT
---TEST---
$TEST_OUTPUT
---BUILD_EXIT_CODE=$BUILD_EXIT
---BUILD---
$BUILD_OUTPUT"
                if [ "$TEST_EXIT" -ne 0 ]; then
                    EXIT_CODE=$TEST_EXIT; STATUS="ERROR"; STDERR="npm test failed."
                elif [ "$BUILD_EXIT" -ne 0 ]; then
                    EXIT_CODE=$BUILD_EXIT; STATUS="ERROR"; STDERR="npm run build failed."
                fi
            fi
            ;;
        project-inspect)
            if [ -z "$PROJECT" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT is required."
            elif [ ! -d "$PROJECT_DIR" ]; then
                STATUS="ERROR"; EXIT_CODE=1; STDERR="Registered project directory does not exist: $PROJECT_DIR"
            else
                STDOUT="PROJECT=$PROJECT
ROOT=$PROJECT_DIR
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
GIT_STATUS:
$(git -C "$PROJECT_DIR" status --short --branch 2>&1)
FILES:
$(find "$PROJECT_DIR" -maxdepth 2 -type f -not -path '*/.git/*' | sed "s#^$PROJECT_DIR/##" | sort | head -200)
PACKAGE_JSON:
$(if [ -f "$PROJECT_DIR/package.json" ]; then cat "$PROJECT_DIR/package.json"; else echo "NO_PACKAGE_JSON"; fi)"
            fi
            ;;
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
        file-write-b64)
            if [ "$SAFE_PATH" != "true" ]; then
                STATUS="BLOCKED"; STDERR="A safe relative PATH is required."
            elif [ -z "$CONTENT_B64" ]; then
                STATUS="BLOCKED"; STDERR="CONTENT_B64 is required."
            else
                mkdir -p "$(dirname "$TARGET")"
                printf '%s' "$CONTENT_B64" | base64 -d > "$TARGET" 2>/dev/null
                EXIT_CODE=$?
                [ "$EXIT_CODE" -eq 0 ] || STATUS="ERROR"
                [ "$STATUS" = "ERROR" ] && STDERR="Invalid base64 content."
                [ "$STATUS" != "ERROR" ] && STDOUT="Wrote $REL_PATH (base64)"
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
        github-repo-create)
            REPO_NAME="$REL_PATH"
            DESCRIPTION="$CONTENT"
            if [ -z "$REPO_NAME" ]; then
                STATUS="BLOCKED"; STDERR="PATH must contain the new GitHub repository name."
            elif printf '%s' "$REPO_NAME" | grep -Eq '[^A-Za-z0-9._-]'; then
                STATUS="BLOCKED"; STDERR="Repository name may contain only letters, numbers, dots, underscores, and hyphens."
            elif gh repo view "$REPO_NAME" >/dev/null 2>&1; then
                STATUS="SUCCESS"
                STDOUT="REPOSITORY_EXISTS=true
REPOSITORY=$REPO_NAME"
            else
                GH_OUTPUT=$(gh repo create "$REPO_NAME" --private --description "$DESCRIPTION" 2>&1)
                EXIT_CODE=$?
                if [ "$EXIT_CODE" -ne 0 ]; then
                    STATUS="ERROR"
                    STDERR="$GH_OUTPUT"
                else
                    STATUS="SUCCESS"
                    STDOUT="REPOSITORY_CREATED=true
REPOSITORY=$REPO_NAME
$GH_OUTPUT"
                fi
            fi
            ;;
        termux-boot-install)
            BOOT_DIR="$HOME/.termux/boot"
            BOOT_SOURCE="$REPO_DIR/boot/start-terhux"
            BOOT_TARGET="$BOOT_DIR/start-terhux"
            if [ ! -f "$BOOT_SOURCE" ]; then
                STATUS="ERROR"
                EXIT_CODE=1
                STDERR="Terhux boot script is missing: $BOOT_SOURCE"
            else
                mkdir -p "$BOOT_DIR"
                cp "$BOOT_SOURCE" "$BOOT_TARGET"
                chmod +x "$BOOT_TARGET"
                EXIT_CODE=$?
                if [ "$EXIT_CODE" -ne 0 ]; then
                    STATUS="ERROR"
                    STDERR="Could not install the Termux:Boot entrypoint."
                else
                    STATUS="SUCCESS"
                    STDOUT="TERMUX_BOOT_INSTALLED=true
BOOT_SCRIPT=$BOOT_TARGET"
                fi
            fi
            ;;
        terhux-start)
            if [ ! -x "$REPO_DIR/terhux-start.sh" ]; then
                chmod +x "$REPO_DIR/terhux-start.sh" "$REPO_DIR/terhux-supervisor.sh" "$REPO_DIR/terhux-watch.sh"
            fi
            nohup "$REPO_DIR/terhux-start.sh" >/dev/null 2>&1 &
            EXIT_CODE=$?
            if [ "$EXIT_CODE" -ne 0 ]; then
                STATUS="ERROR"
                STDERR="Could not start the Terhux supervisor."
            else
                STATUS="SUCCESS"
                STDOUT="TERHUX_STARTED=true"
            fi
            ;;
        netboost-bootstrap)
            if [ -z "$PROJECT_DIR" ]; then
                STATUS="BLOCKED"; STDERR="PROJECT must be registered before bootstrap."
            else
                mkdir -p "$PROJECT_DIR"
                if [ -n "$CONTENT_B64" ]; then
                    TMP_ARCHIVE="$REPO_DIR/.netboost-bootstrap-$COMMAND_ID.tar.gz"
                    printf "%s" "$CONTENT_B64" | base64 -d > "$TMP_ARCHIVE" 2>/dev/null
                    EXTRACT_EXIT=$?
                else
                    TMP_ARCHIVE=""
                    cp -R "$REPO_DIR/netboost-template/." "$PROJECT_DIR/" 2>/dev/null
                    EXTRACT_EXIT=$?
                fi
                if [ "$EXTRACT_EXIT" -ne 0 ]; then
                    STATUS="ERROR"; EXIT_CODE=1; STDERR="Invalid bootstrap archive."
                elif [ -n "$TMP_ARCHIVE" ] && ! tar -xzf "$TMP_ARCHIVE" -C "$PROJECT_DIR" --strip-components=1 2>/dev/null; then
                    STATUS="ERROR"; EXIT_CODE=1; STDERR="Could not extract the NetBoost project archive."
                else
                    cd "$PROJECT_DIR" || exit 1
                    npm install --no-audit --no-fund >/tmp/netboost-npm-install.log 2>&1
                    INSTALL_EXIT=$?
                    TEST_OUTPUT=""; TEST_EXIT=0; BUILD_OUTPUT=""; BUILD_EXIT=0
                    if [ "$INSTALL_EXIT" -eq 0 ]; then TEST_OUTPUT=$(npm test 2>&1); TEST_EXIT=$?; BUILD_OUTPUT=$(npm run build 2>&1); BUILD_EXIT=$?; fi
                    STDOUT="PROJECT_BOOTSTRAPPED=true
PROJECT_DIR=$PROJECT_DIR
NPM_INSTALL_EXIT=$INSTALL_EXIT
TEST_EXIT_CODE=$TEST_EXIT
---TEST---
$TEST_OUTPUT
---BUILD_EXIT_CODE=$BUILD_EXIT
---BUILD---
$BUILD_OUTPUT"
                    if [ "$INSTALL_EXIT" -ne 0 ]; then STATUS="ERROR"; EXIT_CODE=$INSTALL_EXIT; STDERR="npm install failed."; elif [ "$TEST_EXIT" -ne 0 ]; then STATUS="ERROR"; EXIT_CODE=$TEST_EXIT; STDERR="npm test failed."; elif [ "$BUILD_EXIT" -ne 0 ]; then STATUS="ERROR"; EXIT_CODE=$BUILD_EXIT; STDERR="npm run build failed."; else git -C "$PROJECT_DIR" init >/dev/null 2>&1 || true; git -C "$PROJECT_DIR" add . >/dev/null 2>&1 || true; git -C "$PROJECT_DIR" commit -m "Build NetBoost from scratch" >/dev/null 2>&1 || true; if [ ! -d "$PROJECT_DIR/android" ]; then (cd "$PROJECT_DIR" && npx cap add android) >>/tmp/netboost-capacitor.log 2>&1 || true; fi; git -C "$PROJECT_DIR" add . >/dev/null 2>&1 || true; git -C "$PROJECT_DIR" commit -m "Add Capacitor Android platform" >/dev/null 2>&1 || true; if command -v gh >/dev/null 2>&1; then gh repo view Dannygray29/netboost >/dev/null 2>&1 || gh repo create Dannygray29/netboost --private --source "$PROJECT_DIR" --push >/tmp/netboost-gh.log 2>&1 || true; fi; fi
                fi
                rm -f "$TMP_ARCHIVE"
            fi
            ;;
        apk-prepare)
            APK_DIR="$REPO_DIR/apk"
            mkdir -p "$APK_DIR"
            if [ ! -f "$APK_DIR/Terhux.apk" ]; then
                STATUS="BLOCKED"
                STDERR="No Terhux.apk is present. Build the GitHub Actions APK first, then place it at $APK_DIR/Terhux.apk."
            else
                STDOUT="APK_READY=true
APK_PATH=$APK_DIR/Terhux.apk
APK_SIZE=$(wc -c < "$APK_DIR/Terhux.apk")"
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
    echo "STDOUT_BEGIN"
    printf '%s\n' "$STDOUT"
    echo "STDOUT_END"
    echo "STDERR_BEGIN"
    printf '%s\n' "$STDERR"
    echo "STDERR_END"
} > "$RESULT_FILE"

rm -f "$COMMAND_FILE"
if [ "${TERHUX_NO_SYNC:-0}" != "1" ]; then
    git -C "$REPO_DIR" add commands results
    git -C "$REPO_DIR" commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
    git -C "$REPO_DIR" push >/dev/null 2>&1 || true
fi
echo "Command processed: $COMMAND_ID"
