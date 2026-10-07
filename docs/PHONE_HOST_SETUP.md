# Termux Phone Host Setup

Terhux executes on the Android phone, not on GitHub. GitHub Issues carry encrypted requests; GitHub stores result files and issue comments.

## 1. Install prerequisites and clone/update

In Termux, install the runtime tools (skip ones already installed):

```bash
pkg update
pkg install git gh openssl python coreutils
```

Authenticate GitHub CLI as the **repository owner** on the phone and make sure the account can read/write `Dannygray29/terhux`. Clone the private repository if needed, or update the existing clone:

```bash
gh repo clone Dannygray29/terhux ~/terhux/repo
# For an existing clone:
cd ~/terhux/repo
git pull --ff-only
```

The phone needs `gh` for Issues, OpenSSL 3.x for CMS AES-GCM decryption, Python for local PIN verification, and GNU `timeout` from coreutils for bounded actions.

## 2. Initialize phone-only PIN access

From the repository directory, run:

```bash
cd ~/terhux/repo
bash terhux-auth-init.sh
```

The script prompts twice for the PIN without echoing it. It generates a phone-only RSA private key and stores a scrypt verifier in `~/.config/terhux/` with restrictive permissions. It publishes only the public certificate `terhux-access-cert.pem` to the repository. The PIN itself and private key are never committed or placed in GitHub Issues.

The bridge accepts PINs of 4–64 characters and rate-limits failed PIN checks to **5 per GitHub identity and 20 total per rolling 24 hours**. Because the PIN in this conversation is short and has appeared in chat, choose a **new, longer PIN locally** rather than reusing it. A short PIN remains vulnerable to online guessing even though encrypted issues do not expose an offline PIN verifier.

To rotate the PIN and encryption keys later, run:

```bash
bash terhux-auth-init.sh --rotate
```

Use `--rotate` as well when setting up a replacement phone that has the public certificate in the repository but not the phone-local private key/verifier. Rotation invalidates ciphertext made for the old certificate; agents must fetch the new public certificate and create new requests. The private key and PIN verifier remain local.

## 3. Give agents limited GitHub access

In GitHub repository settings, invite each AI agent's own account with **Triage** permission. Triage can create and comment on issues but cannot push code. **Do not grant Write, Maintain, or Admin** to agents. The repository currently has no collaborators beyond the owner. The `terhux-request` label has already been created.

The phone worker polls open issues with that label. Agents submit only encrypted payloads using `terhux-encrypt-request.js`; plaintext PINs and request fields must not be pasted into the issue. See [AI_BRIDGE.md](../AI_BRIDGE.md) for the issue submission protocol and action list.

## 4. Start the phone worker

```bash
cd ~/terhux/repo
chmod +x ./*.sh
./terhux-start.sh
```

A completed request publishes `results/<ID>.result`, comments on its issue with a result link, and closes the issue. Missing setup, malformed ciphertext, or incorrect PIN results in a safe issue comment and removal of the request label; no action runs.

## 5. Start after Android reboot

Install the official Termux:Boot add-on from the same source as Termux. Copy the repository's boot script into the add-on's startup directory:

```bash
mkdir -p ~/.termux/boot
cp ~/terhux/repo/boot/start-terhux ~/.termux/boot/start-terhux
chmod +x ~/.termux/boot/start-terhux
```

Allow Termux to run in the background, exclude it from battery optimization, and keep the phone powered and connected. A wake lock can help prevent CPU sleep but cannot keep a powered-off phone or missing network online. Android force-stop and some OEM battery managers can still stop the bridge.

## 6. Updating/restarting the bridge

After a repository update, stop the old processes so the already-running shell loads the new watcher, then pull, initialize credentials if this is the first issue-mode startup, and restart:

```bash
pkill -f '[t]erhux-supervisor.sh' || true
pkill -f '[t]erhux-watch.sh' || true
cd ~/terhux/repo
git pull --ff-only
bash terhux-auth-init.sh   # first setup only; prompts for the PIN
./terhux-start.sh
```

If the PIN files and certificate already exist, do not run the initializer again unless rotating; it refuses accidental reinitialization. The Termux:Boot script starts the service after reboot, once configured.

## Offline queue, retries, and logs

- Labeled GitHub Issues remain queued while the phone has no network. The worker handles them after it can sync again.
- Local result commits are preserved and retried; the watcher does not use `git reset --hard`.
- `~/terhux/repo/logs/bridge.log` records worker/issue activity. `logs/sync.log` records Git fetch/rebase/push retries. Logs must not contain the PIN; report any unexpected output before sharing logs.
- Delivery is at least once. If the phone stops after an external effect but before the result is published, the action may be retried. Use idempotent work and check state before resubmitting.

## Long-running actions and timeouts

Project build/test/install/deploy actions use a 600-second default wall-time limit. The runner sends `TERM` to the command process group and escalates to `KILL` after five seconds. Captured output is capped at about 256 KiB by default. Results use `STATUS=TIMEOUT` or `STATUS=OUTPUT_LIMIT`; the worker returns to polling afterward.

The phone owner can override the timeout before starting the supervisor, for example:

```bash
export TERHUX_ACTION_TIMEOUT_SECONDS=900
./terhux-start.sh
```

For reboot persistence, put the export in `~/.termux/boot/start-terhux` before the line that starts Terhux. The maximum is 1,800 seconds; agents cannot set it in a request. A missing `timeout` utility causes long-running actions to fail closed. A timeout cannot roll back changes already made by a project script or external service, and these controls are **not an OS sandbox**: deliberately detached processes may escape process-group termination.
