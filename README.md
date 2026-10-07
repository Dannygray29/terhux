# Terhux

Terhux is a **phone-hosted Termux environment with an encrypted GitHub Issues bridge**. The Linux process runs on the owner's Android phone; GitHub provides a request queue and result mailbox, not an always-on VM.

## How it works

1. The owner gives an AI account **Triage** access to this private repository, so it can create issues but cannot push code.
2. The AI encrypts the request and access PIN to the phone's public certificate and opens an issue with the `terhux-request` label.
3. Termux polls GitHub, decrypts the issue locally, rate-limits failed PIN attempts, verifies the PIN, and passes approved structured actions to the allowlisted runner.
4. Results are committed under `results/<id>.result`; the issue receives a result link and is closed. Requests remain queued while the phone is offline.

See [AI_BRIDGE.md](AI_BRIDGE.md) for the request format and [docs/PHONE_HOST_SETUP.md](docs/PHONE_HOST_SETUP.md) for phone setup, PIN initialization, and recovery.

## Security model

- **Do not grant AI agents Write, Maintain, or Admin repository access.** Invite them with **Triage** only. The repository currently has no other collaborators; add each AI account explicitly.
- The PIN is encrypted inside the issue payload with CMS AES-256-GCM and the phone's public certificate. The phone-only private key and a scrypt PIN verifier live outside the repository. The PIN is never put in issue text or Git history.
- Failed access attempts are rate-limited (5 per GitHub identity and 20 total in a rolling 24-hour period). Use a long PIN; a short numeric PIN is still weak against online guessing.
- The `terhux-request` issue label is already created. Only labeled, encrypted issues enter the worker queue.
- Requests use an action allowlist. `APPROVED=true` is a protocol field, not a human approval checkpoint; project scripts can execute code and deploy/rename actions have external effects.

## Availability and execution limits

The environment is available only while the phone is powered on, online, and Termux is allowed to run. Android or an OEM may suspend/stop it; configure battery/background allowances and Termux:Boot. A wake lock cannot keep a powered-off phone or disconnected network available.

The watcher retains local results and retries Git synchronization after outages rather than hard-resetting them away. Processing is best-effort and **at least once**, not exactly once: interruption after an action takes effect can cause a retry. Long-running project actions time out after 10 minutes by default (owner-configurable up to 30 minutes) and captured output is bounded. These are not an OS sandbox; deliberately detached child processes may escape process-group termination.

The execution environment is Termux's Android Linux userland, **not** a GitHub-hosted VM or full Ubuntu server. Phone storage and installed packages persist on that device; they are not automatically backed up by GitHub.

## Start or update the phone worker

After the repository is installed at `~/terhux/repo`, initialize the phone-local access key/PIN before starting the new issue worker:

```bash
cd ~/terhux/repo
bash terhux-auth-init.sh
chmod +x ./*.sh
./terhux-start.sh
```

The initializer publishes only the public certificate. It keeps the private key and PIN verifier in `~/.config/terhux/`. The owner should choose a new PIN locally; do not reuse a short code posted in chat. The repository's `status.txt` is informational, not a live health check.
