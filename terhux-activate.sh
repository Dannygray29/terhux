#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

fail() { echo "Terhux activation failed: $*" >&2; exit 1; }
[ -d "$REPO_DIR/.git" ] || fail "repository not found at $REPO_DIR"
command -v git >/dev/null 2>&1 || fail "install git with: pkg install git"
command -v gh >/dev/null 2>&1 || fail "install GitHub CLI with: pkg install gh"
command -v python3 >/dev/null 2>&1 || fail "install Python with: pkg install python"
gh auth status -h github.com >/dev/null 2>&1 || fail "sign in to GitHub on this phone with: gh auth login"

# Stop the supervisor first so it cannot respawn the old watcher during update.
pkill -f '[t]erhux-supervisor.sh' >/dev/null 2>&1 || true
sleep 1
pkill -f '[t]erhux-watch.sh' >/dev/null 2>&1 || true

restart_old_service() {
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bash "$REPO_DIR/terhux-start.sh" >>"$LOG_DIR/activate.log" 2>&1 || true
  fi
}
trap restart_old_service EXIT

# Preserve locally completed results and queued work before updating the code.
bash "$REPO_DIR/terhux-sync.sh" || fail "could not sync local queue/results; the previous worker was restarted"
git -C "$REPO_DIR" fetch origin main || fail "could not fetch main from GitHub; local changes were preserved"
git -C "$REPO_DIR" merge --ff-only FETCH_HEAD || fail "could not fast-forward to fetched main; local changes were preserved"
chmod +x "$REPO_DIR"/terhux-*.sh "$REPO_DIR/boot/start-terhux"
mkdir -p "$HOME/.termux/boot"
cp "$REPO_DIR/boot/start-terhux" "$HOME/.termux/boot/start-terhux"
chmod +x "$HOME/.termux/boot/start-terhux"
bash "$REPO_DIR/terhux-start.sh"
trap - EXIT

echo "Terhux is activated. Requests now use labeled GitHub Issues; no PIN, certificate, or Actions secret is required."
echo "For automatic startup after reboot, install the Termux:Boot add-on and allow Termux to run in the background."
