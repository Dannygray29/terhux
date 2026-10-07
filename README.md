# Terhux

Terhux is a **single-input GitHub → Termux bridge**.
# Terhux runs on your Android phone in Termux. GitHub is the request queue and result mailbox; GitHub itself does not host the Linux process. The phone can process requests while it is online and Android allows Termux to run in the background.

## How it works

1. An authorized AI agent writes a structured request to `commands/<id>.cmd` on the `main` branch.
2. The Termux worker on the phone polls GitHub (5 seconds by default) and processes requests using the actions allowed by `terhux-runner.sh`.
3. The worker consumes the request and publishes the response to `results/<id>.result`.

See [AI_BRIDGE.md](AI_BRIDGE.md) for the protocol and [docs/PHONE_HOST_SETUP.md](docs/PHONE_HOST_SETUP.md) for phone startup and uptime setup.

## Availability

The environment is available only while the phone is powered on, has working internet, and Termux/the bridge process is running. Android may suspend or stop background apps; allow Termux background activity, exclude it from battery optimization, and install/configure Termux:Boot if it should resume after a phone reboot. A wake lock helps keep the CPU awake but cannot keep a powered-off phone or disconnected network online.

Requests committed to GitHub remain queued while the phone is offline and can be processed after it reconnects. The updated sync helper also keeps local results and retries publishing them instead of resetting them away. This is **best-effort, at-least-once processing**, not an absolute uptime or exactly-once guarantee: a phone shutdown or interruption during an action can cause that action to run again. Avoid non-idempotent actions unless you can safely check for duplicates.

The execution environment is Termux's Android Linux userland, **not** a GitHub-hosted VM or full Ubuntu server. Phone storage and installed packages persist on that device; they are not automatically backed up by GitHub.

## Start or check the phone worker

On the phone, after the repository is installed at `~/terhux/repo`:

```bash
cd ~/terhux/repo
chmod +x ./*.sh
./terhux-start.sh
```

To verify the path end to end, submit a `terhux-runner-version` request as described in [AI_BRIDGE.md](AI_BRIDGE.md), then look for its result in `results/<id>.result`. The repository's `status.txt` is informational and is not a live health check.

## Access and safety

The repository is private. Each AI agent needs GitHub credentials with permission to read results and write requests; GitHub does not automatically grant every AI agent access. Keep it private and grant access only to agents/accounts you trust.

Requests use an action allowlist; arbitrary `COMMAND=` and `COMMAND_B64=` shell requests are disabled. However, `APPROVED=true` is a request-format requirement, **not** a separate human approval gate. Some allowed operations run project scripts or affect external services. Treat agents with repository write access as trusted operators, and do not include secrets in command files or results. See [AI_BRIDGE.md](AI_BRIDGE.md) for the action list and cautions.

## Direct supervisor start

For a manual foreground start, the original supervisor command remains available:
```
cd ~/terhux/repo
./terhux-supervisor.sh
```
