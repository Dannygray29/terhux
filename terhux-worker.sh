#!/data/data/com.termux/files/usr/bin/bash

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RUNNING_DIR="$COMMAND_DIR/.running"
LOCK_DIR="$REPO_DIR/.locks"
SYNC_LOCK="$LOCK_DIR/git-sync.lock"

mkdir -p "$RUNNING_DIR" "$LOCK_DIR"

COMMAND_FILE=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name "*.cmd" | sort | head -n 1)
if [ -z "$COMMAND_FILE" ]; then
    exit 0
fi

CLAIMED="$RUNNING_DIR/$(basename "$COMMAND_FILE")"
if ! mv "$COMMAND_FILE" "$CLAIMED" 2>/dev/null; then
    exit 0
fi

COMMAND_ID=$(basename "$CLAIMED" .cmd)
PROJECT=$(sed -n 's/^PROJECT=//p' "$CLAIMED" | head -n 1)

PROJECT_LOCK=""
if [ -n "$PROJECT" ]; then
    PROJECT_LOCK="$LOCK_DIR/project-$PROJECT.lock"
    while ! mkdir "$PROJECT_LOCK" 2>/dev/null; do
        sleep 1
    done
fi

TERHUX_NO_SYNC=1 "$REPO_DIR/terhux-runner.sh" "$CLAIMED"
RUN_EXIT=$?

if [ -n "$PROJECT_LOCK" ]; then
    rmdir "$PROJECT_LOCK" 2>/dev/null || true
fi

while ! mkdir "$SYNC_LOCK" 2>/dev/null; do
    sleep 1
done
git -C "$REPO_DIR" add commands results
git -C "$REPO_DIR" commit -m "Terhux result: $COMMAND_ID" >/dev/null 2>&1 || true
git -C "$REPO_DIR" pull --rebase --quiet 2>/dev/null || true
git -C "$REPO_DIR" push --quiet 2>/dev/null || true
rmdir "$SYNC_LOCK" 2>/dev/null || true

exit "$RUN_EXIT"
