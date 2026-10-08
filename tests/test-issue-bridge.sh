#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
ORIGIN="$TMP_DIR/origin.git"
BIN_DIR="$TMP_DIR/bin"
mkdir -p "$HOME_DIR" "$REPO_DIR/commands" "$REPO_DIR/results" "$REPO_DIR/logs" "$BIN_DIR"

for file in terhux-issue-worker.py terhux-runner.sh terhux-exec.sh terhux-sync.sh; do
  cp "$ROOT_DIR/$file" "$REPO_DIR/$file"
done

cat > "$BIN_DIR/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
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
git -C "$REPO_DIR" remote add origin "$ORIGIN"
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m 'test base' >/dev/null
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1

cat > "$TMP_DIR/valid-issue.json" <<'JSON'
[{"number":101,"title":"[Terhux] Check runner version","body":"{\"ACTION\":\"terhux-runner-version\",\"APPROVED\":\"true\"}"}]
JSON
: > "$TMP_DIR/valid-comments.txt"
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
  TERHUX_GITHUB_REPO='Dannygray29/terhux-test' TERHUX_REQUEST_LABEL='terhux-request' \
  FAKE_ISSUES="$TMP_DIR/valid-issue.json" FAKE_COMMENTS="$TMP_DIR/valid-comments.txt" \
  FAKE_CLOSED="$TMP_DIR/valid-closed" FAKE_LABEL_REMOVED="$TMP_DIR/valid-label-removed" \
  python3 "$REPO_DIR/terhux-issue-worker.py"
git --git-dir="$ORIGIN" show main:results/issue-101.result | grep -q '^STATUS=SUCCESS$' || { echo 'FAIL: valid issue did not execute' >&2; exit 1; }
grep -q 'TERHUX_RESULT:issue-101' "$TMP_DIR/valid-comments.txt" || { echo 'FAIL: result comment was not posted' >&2; exit 1; }
[ -f "$TMP_DIR/valid-closed" ] || { echo 'FAIL: completed issue was not closed' >&2; exit 1; }

cat > "$TMP_DIR/invalid-issue.json" <<'JSON'
[{"number":102,"title":"[Terhux] Malformed request","body":"not JSON"}]
JSON
: > "$TMP_DIR/invalid-comments.txt"
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
  TERHUX_GITHUB_REPO='Dannygray29/terhux-test' TERHUX_REQUEST_LABEL='terhux-request' \
  FAKE_ISSUES="$TMP_DIR/invalid-issue.json" FAKE_COMMENTS="$TMP_DIR/invalid-comments.txt" \
  FAKE_CLOSED="$TMP_DIR/invalid-closed" FAKE_LABEL_REMOVED="$TMP_DIR/invalid-label-removed" \
  python3 "$REPO_DIR/terhux-issue-worker.py"
if git --git-dir="$ORIGIN" cat-file -e 'refs/heads/main:results/issue-102.result' 2>/dev/null; then
  echo 'FAIL: malformed request was executed' >&2; exit 1
fi
grep -q 'TERHUX:102:REQUEST' "$TMP_DIR/invalid-comments.txt" || { echo 'FAIL: malformed issue did not receive a safe rejection comment' >&2; exit 1; }
[ -f "$TMP_DIR/invalid-label-removed" ] || { echo 'FAIL: malformed issue remained in the active queue' >&2; exit 1; }

echo 'PASS: labeled JSON issues execute through the allowlist, publish results, and malformed issues are rejected.'
