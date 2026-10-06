#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO_DIR="$HOME/terhux/repo"
COMMAND_DIR="$REPO_DIR/commands"
RESULT_DIR="$REPO_DIR/results"
mkdir -p "$COMMAND_DIR" "$RESULT_DIR"

command_file="${1:-}"
if [ -z "$command_file" ]; then
  command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
fi
[ -n "$command_file" ] && [ -f "$command_file" ] || exit 0

id=$(basename "$command_file" .cmd)
raw=$(cat "$command_file")

action=$(printf '%s\n' "$raw" | sed -n 's/^ACTION=//p' | head -n1)
project=$(printf '%s\n' "$raw" | sed -n 's/^PROJECT=//p' | head -n1)
rel_path=$(printf '%s\n' "$raw" | sed -n 's/^PATH=//p' | head -n1)
content=$(printf '%s\n' "$raw" | sed -n 's/^CONTENT=//p' | head -n1)
content_b64=$(printf '%s\n' "$raw" | sed -n 's/^CONTENT_B64=//p' | head -n1)
approved=$(printf '%s\n' "$raw" | sed -n 's/^APPROVED=//p' | head -n1)

status=SUCCESS
exit_code=0
stdout=""
stderr=""

if [ "$approved" != "true" ]; then
  status=BLOCKED
  stderr="APPROVED=true is required."
elif [ -z "$action" ]; then
  status=BLOCKED
  stderr="ACTION is required. Legacy COMMAND/COMMAND_B64 input is disabled."
fi

project_dir=""
case "$project" in
  "") ;;
  terhux) project_dir="$REPO_DIR" ;;
  void) project_dir="$HOME/void" ;;
  netboost) project_dir="$HOME/netboost" ;;
  *) status=BLOCKED; stderr="Unknown project. Project is not registered with Terhux." ;;
esac

safe_path=false
if [ -n "$rel_path" ]; then
  case "$rel_path" in
    /*|../*|*/../*|*/..|..) ;;
    *) safe_path=true ;;
  esac
fi

if [ "$status" = "SUCCESS" ]; then
  case "$action" in
    pwd) stdout=$(pwd) ;;
    whoami) stdout=$(whoami) ;;
    date) stdout=$(date) ;;
    termux-version) stdout=$(termux-info 2>&1 | head -20); exit_code=$? ;;
    netboost-diagnose) cd "$HOME/netboost" 2>/dev/null || { status=ERROR; exit_code=1; stderr="NetBoost directory is missing."; }; if [ "$status" = "SUCCESS" ]; then stdout=$(printf "NODE="; node --version; printf "NPM="; npm --version; printf "JAVA="; (java -version 2>&1 | head -1 || true); printf "CAP="; (npx cap --version 2>&1 || true); printf "ANDROID_DIR="; [ -d android ] && echo yes || echo no; printf "PACKAGE_ANDROID="; node -e "const p=require('./package.json'); console.log(p.dependencies?.['@capacitor/android']||'missing')"; printf "BUILD_CONFIG="; ls vite.config.* tsconfig*.json 2>&1); exit_code=0; fi ;;
    netboost-build) if [ -x "$HOME/netboost/node_modules/.bin/vite" ]; then cd "$HOME/netboost" && npm run build; exit_code=$?; else status=ERROR; exit_code=1; stderr="NetBoost dependencies are not installed."; fi ;;
    netboost-cap-sync) if [ -x "$HOME/netboost/node_modules/.bin/capacitor" ]; then cd "$HOME/netboost" && npm run build >/tmp/netboost-build.log 2>&1 && npx cap sync; exit_code=$?; stdout=$(tail -80 /tmp/netboost-build.log 2>/dev/null); else status=ERROR; exit_code=1; stderr="Capacitor CLI is not installed."; fi ;;
    netboost-android-build) if [ -x "$HOME/netboost/android/gradlew" ]; then cd "$HOME/netboost/android" && ./gradlew assembleDebug; exit_code=$?; else status=ERROR; exit_code=1; stderr="Android project or Gradle wrapper is missing."; fi ;;
    git-version) stdout=$(git --version); exit_code=$? ;;
    node-version) stdout=$(node --version 2>&1); exit_code=$? ;;
    npm-version) stdout=$(npm --version 2>&1); exit_code=$? ;;
    project-list) stdout=$(find "$HOME" -maxdepth 2 -type d -name .git -print 2>/dev/null | sed 's#/.git$##' | sort); exit_code=$? ;;
    git-status)
      if [ -z "$project_dir" ]; then status=BLOCKED; stderr="PROJECT is required."; else stdout=$(git -C "$project_dir" status --short --branch 2>&1); exit_code=$?; fi ;;
    git-branch)
      if [ -z "$project_dir" ]; then status=BLOCKED; stderr="PROJECT is required."; else stdout=$(git -C "$project_dir" branch --show-current 2>&1); exit_code=$?; fi ;;
    file-read)
      if [ "$safe_path" != "true" ] || [ -z "$project_dir" ]; then
        status=BLOCKED; stderr="Registered PROJECT and safe relative PATH are required."
      elif [ ! -f "$project_dir/$rel_path" ]; then
        status=ERROR; exit_code=1; stderr="File does not exist."
      else
        stdout=$(cat "$project_dir/$rel_path" 2>&1); exit_code=$?
      fi ;;
    file-write-b64)
      if [ "$safe_path" != "true" ] || [ -z "$project_dir" ]; then
        status=BLOCKED; stderr="Registered PROJECT and safe relative PATH are required."
      elif [ -z "$content_b64" ]; then
        status=BLOCKED; stderr="CONTENT_B64 is required."
      else
        mkdir -p "$(dirname "$project_dir/$rel_path")"
        printf '%s' "$content_b64" | base64 -d > "$project_dir/$rel_path" 2>/dev/null
        exit_code=$?
        [ "$exit_code" -eq 0 ] && stdout="Wrote $rel_path" || { status=ERROR; stderr="Invalid base64 content."; }
      fi ;;
    *) status=BLOCKED; stderr="Action is not on the Terhux safety allowlist." ;;
  esac
  [ "$exit_code" -eq 0 ] || status=ERROR
fi

{
  echo "TERHUX_RESULT_V1"
  echo "ID=$id"
  echo "ACTION=$action"
  echo "PROJECT=$project"
  echo "PATH=$rel_path"
  echo "APPROVED=$approved"
  echo "STATUS=$status"
  echo "EXIT_CODE=$exit_code"
  echo "TIME=$(date +%s)"
  echo "STDOUT_BEGIN"
  printf '%s\n' "$stdout"
  echo "STDOUT_END"
  echo "STDERR_BEGIN"
  printf '%s\n' "$stderr"
  echo "STDERR_END"
} > "$RESULT_DIR/$id.result"

rm -f "$command_file"
git -C "$REPO_DIR" add commands results >/dev/null 2>&1 || true
git -C "$REPO_DIR" commit -m "Terhux result: $id" >/dev/null 2>&1 || true
git -C "$REPO_DIR" pull --rebase --autostash >/dev/null 2>&1 || true
git -C "$REPO_DIR" push >/dev/null 2>&1 || true
