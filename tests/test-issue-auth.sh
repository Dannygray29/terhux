#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
HOME_DIR="$TMP_DIR/home"
REPO_DIR="$TMP_DIR/repo"
ORIGIN="$TMP_DIR/origin.git"
BIN_DIR="$TMP_DIR/bin"
TEST_PIN='4827'
mkdir -p "$HOME_DIR/.config/terhux" "$REPO_DIR/commands" "$REPO_DIR/results" "$REPO_DIR/logs" "$BIN_DIR"
command -v node >/dev/null || { echo 'SKIP: node is not installed'; exit 0; }
command -v openssl >/dev/null || { echo 'SKIP: openssl is not installed'; exit 0; }

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$HOME_DIR/.config/terhux/access-private.pem" \
  -out "$REPO_DIR/terhux-access-cert.pem" -days 1 -subj '/CN=terhux-test' >/dev/null 2>&1
chmod 600 "$HOME_DIR/.config/terhux/access-private.pem"
printf '%s' "$TEST_PIN" | python3 "$ROOT_DIR/terhux-auth.py" init-pin "$HOME_DIR/.config/terhux/pin-hash.json"
for f in terhux-auth.py terhux-exec.sh terhux-runner.sh terhux-sync.sh terhux-issue-worker.py; do cp "$ROOT_DIR/$f" "$REPO_DIR/$f"; done

cat > "$TMP_DIR/good-fields.json" <<'JSON'
{"ID":"auth-smoke-1","ACTION":"terhux-runner-version","APPROVED":"true"}
JSON
TERHUX_PIN="$TEST_PIN" node "$ROOT_DIR/terhux-encrypt-request.js" "$TMP_DIR/good-fields.json" "$REPO_DIR/terhux-access-cert.pem" > "$TMP_DIR/good-body.txt"
! grep -q "$TEST_PIN" "$TMP_DIR/good-body.txt" || { echo 'FAIL: PIN appeared in the encrypted issue body' >&2; exit 1; }
python3 - "$TMP_DIR/good-body.txt" "$TMP_DIR/good-issue.json" <<'PY'
import json,sys
body=open(sys.argv[1],encoding='utf-8').read().rstrip('\n')
json.dump([{"number":101,"title":"Terhux test","body":body,"author":{"login":"test-agent"}}],open(sys.argv[2],'w'))
PY

cat > "$BIN_DIR/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  'issue list') cat "$FAKE_ISSUES";;
  'issue view') printf '';;
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
git -C "$REPO_DIR" config user.name 'Terhux Auth Test'
git -C "$REPO_DIR" config user.email 'terhux-auth@example.invalid'
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m 'test base' >/dev/null
git -C "$REPO_DIR" remote add origin "$ORIGIN"
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1

PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
  TERHUX_GITHUB_REPO='Dannygray29/terhux-test' TERHUX_REQUEST_LABEL='terhux-request' \
  FAKE_ISSUES="$TMP_DIR/good-issue.json" FAKE_COMMENTS="$TMP_DIR/good-comments.txt" \
  FAKE_CLOSED="$TMP_DIR/good-closed" FAKE_LABEL_REMOVED="$TMP_DIR/good-label-removed" \
  python3 "$REPO_DIR/terhux-issue-worker.py"
git --git-dir="$ORIGIN" show main:results/auth-smoke-1.result | grep -q '^STATUS=SUCCESS$' || { echo 'FAIL: authorized request did not execute' >&2; exit 1; }
grep -q 'TERHUX_RESULT:auth-smoke-1' "$TMP_DIR/good-comments.txt" || { echo 'FAIL: result comment was not posted' >&2; exit 1; }
[ -f "$TMP_DIR/good-closed" ] || { echo 'FAIL: completed issue was not closed' >&2; exit 1; }

cat > "$TMP_DIR/bad-fields.json" <<'JSON'
{"ID":"auth-smoke-bad","ACTION":"terhux-runner-version","APPROVED":"true"}
JSON
TERHUX_PIN='0000' node "$ROOT_DIR/terhux-encrypt-request.js" "$TMP_DIR/bad-fields.json" "$REPO_DIR/terhux-access-cert.pem" > "$TMP_DIR/bad-body.txt"
python3 - "$TMP_DIR/bad-body.txt" "$TMP_DIR/bad-issue.json" <<'PY'
import json,sys
body=open(sys.argv[1],encoding='utf-8').read().rstrip('\n')
json.dump([{"number":102,"title":"Terhux bad PIN test","body":body,"author":{"login":"test-agent"}}],open(sys.argv[2],'w'))
PY
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
  TERHUX_GITHUB_REPO='Dannygray29/terhux-test' TERHUX_REQUEST_LABEL='terhux-request' \
  FAKE_ISSUES="$TMP_DIR/bad-issue.json" FAKE_COMMENTS="$TMP_DIR/bad-comments.txt" \
  FAKE_CLOSED="$TMP_DIR/bad-closed" FAKE_LABEL_REMOVED="$TMP_DIR/bad-label-removed" \
  python3 "$REPO_DIR/terhux-issue-worker.py"
if git --git-dir="$ORIGIN" cat-file -e 'refs/heads/main:results/auth-smoke-bad.result' 2>/dev/null; then echo 'FAIL: incorrect PIN request was executed' >&2; exit 1; fi
grep -q 'TERHUX_AUTH:102:DENIED' "$TMP_DIR/bad-comments.txt" || { echo 'FAIL: incorrect PIN was not rejected' >&2; exit 1; }
[ -f "$TMP_DIR/bad-label-removed" ] || { echo 'FAIL: rejected issue remained in the active queue' >&2; exit 1; }

for number in 103 104 105 106; do
  python3 - "$TMP_DIR/bad-body.txt" "$TMP_DIR/repeat-issue.json" "$number" <<'PY'
import json,sys
body=open(sys.argv[1],encoding='utf-8').read().rstrip('\n')
json.dump([{"number":int(sys.argv[3]),"title":"Terhux repeated PIN test","body":body,"author":{"login":"test-agent"}}],open(sys.argv[2],'w'))
PY
  PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
    TERHUX_GITHUB_REPO='Dannygray29/terhux-test' TERHUX_REQUEST_LABEL='terhux-request' \
    FAKE_ISSUES="$TMP_DIR/repeat-issue.json" FAKE_COMMENTS="$TMP_DIR/repeat-comments.txt" \
    FAKE_CLOSED="$TMP_DIR/repeat-closed" FAKE_LABEL_REMOVED="$TMP_DIR/repeat-label-removed" \
    python3 "$REPO_DIR/terhux-issue-worker.py"
done
cat > "$TMP_DIR/locked-fields.json" <<'JSON'
{"ID":"locked-out","ACTION":"terhux-runner-version","APPROVED":"true"}
JSON
TERHUX_PIN="$TEST_PIN" node "$ROOT_DIR/terhux-encrypt-request.js" "$TMP_DIR/locked-fields.json" "$REPO_DIR/terhux-access-cert.pem" > "$TMP_DIR/locked-body.txt"
python3 - "$TMP_DIR/locked-body.txt" "$TMP_DIR/locked-issue.json" <<'PY'
import json,sys
body=open(sys.argv[1],encoding='utf-8').read().rstrip('\n')
json.dump([{"number":107,"title":"Terhux lockout test","body":body,"author":{"login":"test-agent"}}],open(sys.argv[2],'w'))
PY
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" TERHUX_REPO_DIR="$REPO_DIR" \
  TERHUX_GITHUB_REPO='Dannygray29/terhux-test' TERHUX_REQUEST_LABEL='terhux-request' \
  FAKE_ISSUES="$TMP_DIR/locked-issue.json" FAKE_COMMENTS="$TMP_DIR/locked-comments.txt" \
  FAKE_CLOSED="$TMP_DIR/locked-closed" FAKE_LABEL_REMOVED="$TMP_DIR/locked-label-removed" \
  python3 "$REPO_DIR/terhux-issue-worker.py"
grep -q 'TERHUX_AUTH:107:LOCKED' "$TMP_DIR/locked-comments.txt" || { echo 'FAIL: repeated bad PINs did not trigger lockout' >&2; exit 1; }
if git --git-dir="$ORIGIN" cat-file -e 'refs/heads/main:results/locked-out.result' 2>/dev/null; then echo 'FAIL: locked-out request was executed' >&2; exit 1; fi
echo 'PASS: encrypted issue requests execute only with the local PIN; incorrect PINs are rejected.'
