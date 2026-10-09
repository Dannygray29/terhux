# Termux Phone Setup

Terhux runs on the Android phone in Termux. The phone polls GitHub Issues for shell commands and returns output as issue comments. GitHub is only the mailbox; the code checkout is not used to transport jobs or results.

## 1. Install and sign in once

In Termux:

```bash
pkg update
pkg install git gh python coreutils
gh auth login
```

The phone's GitHub CLI account must be able to read the private repository and write issue comments/close issues. Clone the repository if needed:

```bash
gh repo clone Dannygray29/terhux ~/terhux/repo
```

## 2. Activate the issue bridge

For a new clone:

```bash
cd ~/terhux/repo && bash ./terhux-activate.sh
```

For an existing checkout, update it without `git pull` and activate:

```bash
cd ~/terhux/repo && git fetch origin main && git merge --ff-only FETCH_HEAD && bash ./terhux-activate.sh
```

The update helper uses one explicit fetch and a fast-forward-only merge. It refuses to overwrite tracked local edits and does not reset the checkout. The activation script starts one issue watcher, installs `~/.termux/boot/start-terhux`, and stops retired HTTP/relay and legacy worker services. Let any old job finish before this one-time cutover; stopping an old worker mid-command can leave partial side effects. The normal bridge requires no PIN, certificate, Actions secret, relay URL, or public phone port.

## 3. Let AI agents use Termux

In GitHub repository settings, grant **Triage** only to AI accounts you fully trust. This permission is the remote shell authorization boundary: any Triage agent able to apply `terhux-request` can run shell commands as the Termux user. Do not grant access to untrusted agents or give agents broader repository roles than needed.

An AI creates a `[Terhux]` issue with the `terhux-request` label and places a raw Bash command/script in the body. It reads the issue comments for `TERHUX_STARTED` and `TERHUX_RESULT`. GitHub/MCP clients need issue-create-with-label and issue-comments/read operations; GitHub's remote MCP endpoint is `https://api.githubcopilot.com/mcp/`.

Each request runs in a fresh login Bash starting at the Termux home directory. To work in a project, the AI includes `cd ~/project && ...` in that request. Shell variables and the current directory do not persist between issues.

## 4. Start after reboot

Install the official Termux:Boot add-on from the same source as Termux. The activation script installs the boot launcher. Allow Termux to run in the background and exclude it from battery optimization. Android/OEM restrictions can still stop it; the phone must be powered on and connected.

## State and updates

- GitHub Issues remain queued while the phone is offline; polling defaults to about five seconds.
- Commands, result receipts, locks, and logs are stored under `~/.local/state/terhux`, outside the repository.
- The result comment contains status and up to 30 KB of output. Output beyond that is clipped; the Termux runner also applies a bounded output capture.
- The worker does not commit or push any job data. There is no per-request Git sync and no `git pull` in the active bridge. The boot/activation update uses `git fetch` plus `git merge --ff-only FETCH_HEAD` only.
- Delivery is at least once. If Termux stops after a command's side effect but before its result is saved and posted, it may be retried. Check the issue before resubmitting.

## Timeouts

The default command wall-time limit is 600 seconds; the owner can set `TERHUX_ACTION_TIMEOUT_SECONDS` up to 1,800 seconds before starting the supervisor. Output capture is bounded (about 256 KiB by default) and the issue comment is capped separately. A timeout can leave partial side effects; a process deliberately detached by a command may outlive the timeout. These limits are not a security sandbox.
