# Termux Phone Host Setup

Terhux executes on the Android phone inside Termux. GitHub Issues are the request and result channel; no GitHub Actions runner or Actions secret is involved.

## 1. Install prerequisites and authenticate GitHub

In Termux, install the tools used by the watcher and bounded runner:

```bash
pkg update
pkg install git gh python coreutils
```

Authenticate GitHub CLI on the phone as the repository owner (or an account with the repository access needed to sync requests/results):

```bash
gh auth login
```

Clone the private repository if it is not present, or update the existing checkout:

```bash
gh repo clone Dannygray29/terhux ~/terhux/repo
# Existing checkout:
cd ~/terhux/repo
git pull --ff-only
```

## 2. Activate the bridge once

Run this one command in Termux:

```bash
cd ~/terhux/repo && git pull --ff-only origin main && bash ./terhux-activate.sh
```

It preserves pending local queue/results, pulls the latest `main`, installs the boot launcher, and starts the supervisor/worker. **There is no PIN, certificate, encryption helper, or Actions-secret setup.** The `gh` login on the phone is used for polling Issues and syncing results.

## 3. Give AI agents issue access

In GitHub repository settings, invite each trusted AI account with **Triage** permission. Do not grant AI agents Write, Maintain, or Admin access. Triage is the authorization boundary: agents that can create labeled issues can submit any action in the documented allowlist. Keep the invite list limited to agents you trust.

The queue label `terhux-request` already exists. An AI submits a `[Terhux]` issue with a JSON body and that label. See [AI_BRIDGE.md](../AI_BRIDGE.md) for the JSON format and MCP examples.

For MCP-connected agents, connect a GitHub Issues-capable MCP server to an account with Triage access. GitHub's official remote MCP endpoint is `https://api.githubcopilot.com/mcp/`; the client needs issue-create and issue-comment/read operations. The phone does not need to know which AI or MCP client created the issue.

## 4. Start after Android reboot

The activation script copies `boot/start-terhux` into `~/.termux/boot/`. Install the official Termux:Boot add-on from the same source as Termux if you have not already done so. Allow Termux to run in the background and exclude it from battery optimization. Android or an OEM may still stop the process; a wake lock cannot keep a powered-off phone or disconnected network available.

## Updating/restarting

Run `bash ~/terhux/repo/terhux-activate.sh` again after an update. It first syncs local queue/results, then fast-forwards without discarding local work and restarts the worker. The Termux:Boot script pulls `main` and starts the supervisor after reboot.

## Queue, results, and logs

- Labeled GitHub Issues remain queued while the phone has no network.
- The worker processes requests sequentially, posts the result and a link to `results/issue-<number>.result`, then closes the issue.
- Local result commits are preserved and retried; the sync loop does not use `git reset --hard`.
- `~/terhux/repo/logs/bridge.log` records issue activity. `logs/sync.log` records Git fetch/rebase/push retries. Do not put credentials in issue bodies or share logs containing sensitive project output.
- Delivery is at least once. If the phone stops after an external effect but before the result is published, a retry can repeat work.

## Long-running actions and timeouts

Project build/test/install/deploy actions use a 600-second default wall-time limit. The runner sends `TERM` to the command process group and escalates to `KILL` after five seconds. Captured output is capped at about 256 KiB by default. Results use `STATUS=TIMEOUT` or `STATUS=OUTPUT_LIMIT`; the worker returns to polling afterward.

The phone owner can override the timeout before starting the supervisor, for example:

```bash
export TERHUX_ACTION_TIMEOUT_SECONDS=900
bash ~/terhux/repo/terhux-start.sh
```

The maximum is 1,800 seconds; agents cannot set it in a request. A missing `timeout` utility causes long-running actions to fail closed. A timeout cannot roll back changes already made by a project script or external service, and these controls are **not an OS sandbox**: deliberately detached processes may escape process-group termination.
