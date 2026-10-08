# Terhux

Terhux is a **Linux command environment running on an Android phone in Termux**. GitHub Issues carry requests to the phone and carry results back to the AI. The bridge works with any AI that can create and read issues through GitHub or a GitHub MCP server.

## The simple flow

1. Give a trusted AI's GitHub account **Triage** permission on this private repository. Do not give AI accounts code-write access.
2. The AI opens an issue titled `[Terhux] ...`, puts a JSON request in the body, and adds the `terhux-request` label.
3. Termux polls labeled issues, passes each structured request to the existing bounded action allowlist, and commits the result.
4. The phone comments on and closes the issue. The AI reads that reply or `results/issue-<number>.result`.

**No GitHub Actions secret, public certificate, PIN, or encryption helper is required.** Repository access and the ability to apply the request label are the access gate. Only grant Triage to agents you trust to run the documented actions.

See [AI_BRIDGE.md](AI_BRIDGE.md) for the request format and MCP examples, [CLAUDE_TERHUX.md](CLAUDE_TERHUX.md) for connecting MCP-capable agents, and [docs/PHONE_HOST_SETUP.md](docs/PHONE_HOST_SETUP.md) for the one-time phone activation.

## Request safety

Requests are JSON fields, not shell commands. The phone accepts only the runner's fixed action allowlist; it validates paths and bounds action time and captured output. Some allowed actions can write project files, install dependencies, deploy, or rename a repository. `APPROVED="true"` is a protocol field, not a separate owner approval step. A Triage collaborator can therefore submit any documented action; invite agents accordingly.

## Availability and limits

The execution environment is Termux's Android Linux userland, **not** an always-on GitHub VM. It is available only while the phone is powered on, online, and Android allows Termux to run. Requests stay queued in GitHub while the phone is offline. Termux:Boot and background/battery settings help resume it after reboots, but cannot keep a powered-off phone or missing network online.

Local completed results and pending bridge files are retained and retried after network outages. Delivery is best-effort and **at least once**, not exactly once: an interruption after an external side effect can cause a retry. Check the issue/result before resubmitting after a timeout. These timeouts are not an OS security sandbox; deliberately detached project processes may outlive a command.

## One-time activation

After Termux and GitHub CLI are installed and GitHub is authenticated on the phone, run:

```bash
cd ~/terhux/repo && git pull --ff-only origin main && bash ./terhux-activate.sh
```

This syncs pending work, updates the code, copies the Termux:Boot launcher, and starts the worker. No PIN or secret setup is involved. The status file is informational, not a live health check.
