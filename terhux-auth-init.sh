#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO_DIR="${TERHUX_REPO_DIR:-$HOME/terhux/repo}"
CONFIG_DIR="$HOME/.config/terhux"
PRIVATE_KEY="$CONFIG_DIR/access-private.pem"
PIN_HASH="$CONFIG_DIR/pin-hash.json"
PUBLIC_CERT="$REPO_DIR/terhux-access-cert.pem"
ROTATE=false
[ "${1:-}" = "--rotate" ] && ROTATE=true

command -v openssl >/dev/null || { echo 'Install OpenSSL first: pkg install openssl' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Install Python first: pkg install python' >&2; exit 1; }
OPENSSL_VERSION=$(openssl version | awk '{print $2}')
OPENSSL_MAJOR=${OPENSSL_VERSION%%.*}
[ "$OPENSSL_MAJOR" -ge 3 ] || { echo 'OpenSSL 3.x is required for authenticated CMS AES-GCM.' >&2; exit 1; }
[ -d "$REPO_DIR/.git" ] || { echo "Terhux repo not found at $REPO_DIR" >&2; exit 1; }
if [ "$ROTATE" != true ] && { [ -e "$PRIVATE_KEY" ] || [ -e "$PIN_HASH" ] || [ -e "$PUBLIC_CERT" ]; }; then
  echo 'Terhux access credentials already exist. Use --rotate only to replace them.' >&2
  exit 1
fi

umask 077
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
TMP_DIR=$(mktemp -d "$CONFIG_DIR/setup.XXXXXX")
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

read -r -s -p 'Choose a Terhux access PIN (4-64 characters): ' PIN1
printf '\n'
read -r -s -p 'Enter it again: ' PIN2
printf '\n'
[ "$PIN1" = "$PIN2" ] || { unset PIN1 PIN2; echo 'PINs did not match.' >&2; exit 1; }
printf '%s' "$PIN1" | python3 "$REPO_DIR/terhux-auth.py" init-pin "$TMP_DIR/pin-hash.json"
unset PIN1 PIN2

if ! openssl req -x509 -newkey rsa:3072 -nodes \
  -keyout "$TMP_DIR/access-private.pem" \
  -out "$TMP_DIR/terhux-access-cert.pem" \
  -days 3650 -subj '/CN=Terhux issue access' >"$TMP_DIR/openssl.log" 2>&1; then
  cat "$TMP_DIR/openssl.log" >&2
  exit 1
fi
chmod 600 "$TMP_DIR/access-private.pem"
chmod 600 "$TMP_DIR/pin-hash.json"

mv -f "$TMP_DIR/access-private.pem" "$PRIVATE_KEY"
mv -f "$TMP_DIR/pin-hash.json" "$PIN_HASH"
cp "$TMP_DIR/terhux-access-cert.pem" "$PUBLIC_CERT"
chmod 644 "$PUBLIC_CERT"
rm -f "$CONFIG_DIR/auth-failures.json"

cd "$REPO_DIR"
git add -- terhux-access-cert.pem
git -c user.name='Terhux Phone' -c user.email='terhux-phone@users.noreply.github.com' \
  commit -m 'Publish Terhux issue encryption certificate'
bash "$REPO_DIR/terhux-sync.sh"

echo 'Terhux issue access initialized.'
echo "Private key and PIN verifier are local-only under $CONFIG_DIR."
echo 'Only the public certificate was published to GitHub.'
echo 'Add AI agents as Triage collaborators; do not grant code-write access.'
