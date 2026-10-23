#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
STATE_DIR="$TMP_DIR/state"
ORIGIN="$TMP_DIR/origin.git"
BIN_DIR="$TMP_DIR/bin"
mkdir -p "$HOME_DIR" "$REPO_DIR" "$BIN_DIR"
for file in terhux-issue-worker.py terhux-runner.sh terhux-exec.sh .gitignore; do
  cp "$ROOT_DIR/$file" "$REPO_DIR/$file"
done

cat > "$BIN_DIR/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
# GitHub CLI global flags appear before the subcommand.
if [ "${1:-}" = "--repo" ]; then shift 2; fi
case "${1:-} ${2:-}" in
  'issue list')
    [[ " $* " == *" --label terhux-request "* ]] || { echo 'worker did not filter by queue label' >&2; exit 3; }
    cat "$FAKE_ISSUES";;
  'issue view')
    [ -f "$FAKE_COMMENTS" ] && cat "$FAKE_COMMENTS" || true;;
  'issue comment')
    body=''
    while [ "$#" -gt 0 ]; do
      if [ "$1" = '--body' ]; then body="$2"; shift 2; else shift; fi
    done
    printf '%s\n' "$body" >> "$FAKE_COMMENTS";;
  'issue close') : > "$FAKE_CLOSED";;
  'issue edit') : > "$FAKE_LABEL_REMOVED";;
  *) echo "unexpected gh call: $*" >&2; exit 2;;
esac
GH
chmod +x "$BIN_DIR/gh"

git init --bare --initial-branch=main "$ORIGIN" >/dev/null
git init --initial-branch=main "$REPO_DIR" >/dev/null
git -C "$REPO_DIR" config user.name 'Terhux Bridge Test'
git -C "$REPO_DIR" config user.email 'terhux-bridge@example.invalid'
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m 'test base' >/dev/null
git -C "$REPO_DIR" remote add origin "$ORIGIN"
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1
BASE_HEAD="$(git -C "$REPO_DIR" rev-parse HEAD)"

run_worker() {
  PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
    TERHUX_STATE_DIR="$STATE_DIR" TERHUX_GITHUB_REPO='Dannygray29/terhux-test' \
    TERHUX_REQUEST_LABEL='terhux-request' FAKE_ISSUES="$1" FAKE_COMMENTS="$2" \
    FAKE_CLOSED="$3" FAKE_LABEL_REMOVED="$4" python3 "$REPO_DIR/terhux-issue-worker.py"
}

python3 - "$TMP_DIR/raw-issue.json" <<'PY'
import json, sys
json.dump([{
    "number": 101,
    "title": "[Terhux] Run a raw shell smoke test",
    "body": "TERHUX-SHELL-V1" + chr(10) + "printf 'RAW_SHELL_OK\\n'" + chr(10) + "printf 'PWD=%s\\n' \"$PWD\"" + chr(10),
    "labels": [{"name": "terhux-request"}],
}], open(sys.argv[1], "w"))
PY
: > "$TMP_DIR/raw-comments.txt"
run_worker "$TMP_DIR/raw-issue.json" "$TMP_DIR/raw-comments.txt" "$TMP_DIR/raw-closed" "$TMP_DIR/raw-label-removed"
RESULT="$STATE_DIR/results/issue-101.result"
grep -q '^STATUS=SUCCESS$' "$RESULT" || { cat "$RESULT"; echo 'FAIL: raw shell request did not succeed' >&2; exit 1; }
grep -q 'RAW_SHELL_OK' "$RESULT" || { cat "$RESULT"; echo 'FAIL: shell output was not recorded locally' >&2; exit 1; }
grep -q 'TERHUX_STARTED:issue-101' "$TMP_DIR/raw-comments.txt" || { echo 'FAIL: start marker was not posted' >&2; exit 1; }
grep -q 'TERHUX_RESULT:issue-101' "$TMP_DIR/raw-comments.txt" || { echo 'FAIL: result comment was not posted' >&2; exit 1; }
grep -q 'RAW_SHELL_OK' "$TMP_DIR/raw-comments.txt" || { echo 'FAIL: shell output was not returned in the comment' >&2; exit 1; }
[ -f "$TMP_DIR/raw-closed" ] || { echo 'FAIL: completed issue was not closed' >&2; exit 1; }
[ "$(git -C "$REPO_DIR" rev-parse HEAD)" = "$BASE_HEAD" ] || { echo 'FAIL: job handling created a local Git commit' >&2; exit 1; }
if git --git-dir="$ORIGIN" ls-tree -r --name-only main | grep -q '^results/issue-101.result$'; then
  echo 'FAIL: job result was pushed into the Git repository' >&2; exit 1
fi
[ -z "$(git -C "$REPO_DIR" status --porcelain)" ] || { echo 'FAIL: job handling dirtied the code checkout' >&2; exit 1; }

python3 - "$TMP_DIR/large-issue.json" <<'PY'
import json, sys
json.dump([{
    "number": 104,
    "title": "[Terhux] Verify clipped output comment",
    "body": "TERHUX-SHELL-V1" + chr(10) + "python3 -c 'print(chr(96) * 40000)'",
    "labels": [{"name": "terhux-request"}],
}], open(sys.argv[1], "w"))
PY
: > "$TMP_DIR/large-comments.txt"
run_worker "$TMP_DIR/large-issue.json" "$TMP_DIR/large-comments.txt" "$TMP_DIR/large-closed" "$TMP_DIR/large-label-removed"
python3 - "$TMP_DIR/large-comments.txt" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
assert len(text.encode("utf-8")) < 65_536, "GitHub comment exceeds the issue-comment size limit"
assert text.splitlines().count("```") == 1, "command output escaped the Markdown code block"
assert "\u200b" in text, "fence-like command output was not neutralized"
assert "output clipped" in text
PY

python3 - "$TMP_DIR/empty-issue.json" <<'PY'
import json, sys
json.dump([{
    "number": 102,
    "title": "[Terhux] Empty command is rejected",
    "body": "",
    "labels": [{"name": "terhux-request"}],
}], open(sys.argv[1], "w"))
PY
: > "$TMP_DIR/empty-comments.txt"
run_worker "$TMP_DIR/empty-issue.json" "$TMP_DIR/empty-comments.txt" "$TMP_DIR/empty-closed" "$TMP_DIR/empty-label-removed"
grep -q 'TERHUX:102:REQUEST' "$TMP_DIR/empty-comments.txt" || { echo 'FAIL: empty command was not rejected' >&2; exit 1; }
[ -f "$TMP_DIR/empty-label-removed" ] || { echo 'FAIL: invalid issue remained in the active queue' >&2; exit 1; }

python3 - "$TMP_DIR/legacy-issue.json" <<'PY'
import json, sys
json.dump([{
    "number": 103,
    "title": "[Terhux] Legacy runner-version compatibility",
    "body": '{"ACTION":"terhux-runner-version","APPROVED":"true"}',
    "labels": [{"name": "terhux-request"}],
}], open(sys.argv[1], "w"))
PY
: > "$TMP_DIR/legacy-comments.txt"
run_worker "$TMP_DIR/legacy-issue.json" "$TMP_DIR/legacy-comments.txt" "$TMP_DIR/legacy-closed" "$TMP_DIR/legacy-label-removed"
grep -q '^STATUS=SUCCESS$' "$STATE_DIR/results/issue-103.result" || { echo 'FAIL: queued legacy smoke request did not complete' >&2; exit 1; }
grep -q 'TERHUX_RUNNER_OK' "$TMP_DIR/legacy-comments.txt" || { echo 'FAIL: legacy smoke result was not returned' >&2; exit 1; }

echo 'PASS: raw shell runs in Termux, start/result comments return output, legacy smoke issues work, and job data stays out of Git.'
