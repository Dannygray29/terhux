#!/data/data/com.termux/files/usr/bin/bash
set -e
BASE="$HOME/terhux2"
REPO="$BASE/repo"
mkdir -p "$BASE"
if [ ! -d "$REPO/.git" ]; then
  git clone --branch terhux2 https://github.com/Dannygray29/terhux.git "$REPO"
fi
mkdir -p "$REPO/commands" "$REPO/results"
chmod +x "$REPO/terhux2-runner.sh"
echo "TERHUX2_INSTALLED"
echo "PATH=$REPO"
