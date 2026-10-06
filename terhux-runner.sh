#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO_DIR="$HOME/terhux/repo"; COMMAND_DIR="$REPO_DIR/commands"; RESULT_DIR="$REPO_DIR/results"
mkdir -p "$COMMAND_DIR" "$RESULT_DIR"
command_file="${1:-}"; [ -n "$command_file" ] || command_file=$(find "$COMMAND_DIR" -maxdepth 1 -type f -name '*.cmd' | sort | head -n1)
[ -n "$command_file" ] && [ -f "$command_file" ] || exit 0
id=$(basename "$command_file" .cmd); raw=$(cat "$command_file")
action=$(printf '%s\n' "$raw"|sed -n 's/^ACTION=//p'|head -n1); project=$(printf '%s\n' "$raw"|sed -n 's/^PROJECT=//p'|head -n1); rel_path=$(printf '%s\n' "$raw"|sed -n 's/^PATH=//p'|head -n1); approved=$(printf '%s\n' "$raw"|sed -n 's/^APPROVED=//p'|head -n1)
status=SUCCESS; exit_code=0; stdout=""; stderr=""
[ "$approved" = true ] || { status=BLOCKED; stderr="APPROVED=true is required."; }
[ -n "$action" ] || { status=BLOCKED; stderr="ACTION is required."; }
valid_project() { [ -n "$project" ] && [[ "$project" =~ ^[A-Za-z0-9._-]+$ ]]; }
project_dir="$HOME/$project"
if [ "$status" = SUCCESS ]; then
case "$action" in
terhux-runner-version)
  stdout="TERHUX_RUNNER_OK"
  ;;
project-install)
  valid_project && [ -d "$project_dir" ] || { status=BLOCKED; exit_code=1; stderr="Invalid or missing project."; }
  [ "$status" = SUCCESS ] && { stdout=$(cd "$project_dir" && npm install 2>&1); exit_code=$?; }
  ;;
project-build)
  valid_project && [ -d "$project_dir" ] || { status=BLOCKED; exit_code=1; stderr="Invalid or missing project."; }
  [ "$status" = SUCCESS ] && { stdout=$(cd "$project_dir" && npm run build 2>&1); exit_code=$?; }
  ;;
project-test)
  valid_project && [ -d "$project_dir" ] || { status=BLOCKED; exit_code=1; stderr="Invalid or missing project."; }
  [ "$status" = SUCCESS ] && { stdout=$(cd "$project_dir" && npm test 2>&1); exit_code=$?; }
  ;;
project-android)
  valid_project && [ -d "$project_dir" ] || { status=BLOCKED; exit_code=1; stderr="Invalid or missing project."; }
  [ "$status" = SUCCESS ] && { stdout=$(cd "$project_dir" && npm run android 2>&1); exit_code=$?; }
  ;;
*)
  status=BLOCKED
  exit_code=1
  stderr="Action is not on the Terhux core allowlist."
  ;;
esac
fi
[ "$exit_code" -eq 0 ] || [ "$status" = BLOCKED ] || status=ERROR
{ echo TERHUX_RESULT_V1; echo "ID=$id"; echo "ACTION=$action"; echo "PROJECT=$project"; echo "PATH=$rel_path"; echo "APPROVED=$approved"; echo "STATUS=$status"; echo "EXIT_CODE=$exit_code"; echo "TIME=$(date +%s)"; echo STDOUT_BEGIN; printf '%s\n' "$stdout"; echo STDOUT_END; echo STDERR_BEGIN; printf '%s\n' "$stderr"; echo STDERR_END; } >"$RESULT_DIR/$id.result"
rm -f "$command_file"
git -C "$REPO_DIR" add commands results >/dev/null 2>&1||true
git -C "$REPO_DIR" commit -m "Terhux result: $id" >/dev/null 2>&1||true
for attempt in 1 2 3 4 5; do
  if git -C "$REPO_DIR" fetch origin main >/dev/null 2>&1 && git -C "$REPO_DIR" rebase origin/main >/dev/null 2>&1 && git -C "$REPO_DIR" push origin HEAD:main >/dev/null 2>&1; then break; fi
  git -C "$REPO_DIR" rebase --abort >/dev/null 2>&1 || true
  sleep 2
done
