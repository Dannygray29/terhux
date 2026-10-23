#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${TERHUX_STATE_DIR:-$STATE_BASE/terhux}"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR"
fail() { echo "Terhux activation failed: $*" >&2; exit 1; }
[ -d "$REPO_DIR/.git" ] || fail "repository not found at $REPO_DIR"
command -v git >/dev/null 2>&1 || fail "install git with: pkg install git"
command -v gh >/dev/null 2>&1 || fail "install GitHub CLI with: pkg install gh"
command -v python3 >/dev/null 2>&1 || fail "install Python with: pkg install python"
gh auth status -h github.com >/dev/null 2>&1 || fail "sign in to GitHub on this phone with: gh auth login"

# Stop the service before updating so an old watcher cannot respawn mid-update.
pkill -f '[t]erhux-supervisor.sh' >/dev/null 2>&1 || true
sleep 1
pkill -f '[t]erhux-watch.sh' >/dev/null 2>&1 || true
# The direct HTTP and relay servers are retired; GitHub Issues is the single active path.
pkill -f '[t]erhux-direct.py' >/dev/null 2>&1 || true
pkill -f '[t]erhux-relay.py' >/dev/null 2>&1 || true
# Disable old runit queues and standalone workers so they cannot consume the same work.
if command -v sv >/dev/null 2>&1; then
  sv down terhux >/dev/null 2>&1 || true
  sv down terhux2 >/dev/null 2>&1 || true
fi
for old_worker in '[t]erhux-worker.sh' '[t]erhux-controller.sh' '[t]erhux-task.sh' '[t]erhux-ai-agent.js' '[t]erhux2-runner.sh'; do
  pkill -f "$old_worker" >/dev/null 2>&1 || true
done

restart_old_service() {
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bash "$REPO_DIR/terhux-start.sh" >>"$LOG_DIR/activate.log" 2>&1 || true
  fi
}
trap restart_old_service EXIT

bash "$REPO_DIR/terhux-sync.sh" || fail "safe code update failed; local state was preserved"
chmod +x "$REPO_DIR/boot/start-terhux"
mkdir -p "$HOME/.termux/boot"
cp "$REPO_DIR/boot/start-terhux" "$HOME/.termux/boot/start-terhux"
chmod +x "$HOME/.termux/boot/start-terhux"
bash "$REPO_DIR/terhux-start.sh"
trap - EXIT

echo "Terhux is active: AI shell commands go through labeled GitHub Issues and results return as comments."
echo "Job requests/results are local state, not Git commits. Termux:Boot can restart the watcher after reboot."
