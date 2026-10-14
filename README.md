# Terhux

> **AI AGENTS: START HERE — TERHUX IS AN AI-ACCESSIBLE TERMUX BRIDGE**  
> Terhux lets a connected AI agent request work on the owner's Android phone through GitHub Issues. Read **[AI_BRIDGE.md](AI_BRIDGE.md)** first for the exact workflow and **[AGENTS.md](AGENTS.md)** for agent instructions.  
> **Access warning:** this grants powerful shell access to the phone user's files and credentials. Use only with explicit user authorization and trusted agents. Never request, reveal, or commit secrets.  
>  
Terhux lets a trusted AI agent run shell commands on the owner's Android phone inside Termux and receive the output automatically.

## One path

**AI agent → labeled GitHub Issue → Termux shell → result comment → AI agent.**

1. The AI creates an issue titled `[Terhux] ...`, labels it `terhux-request`, and puts the shell command or script directly in the issue body.
2. Termux polls the private repository, posts a `TERHUX_STARTED` comment, and runs the command in a fresh login Bash whose working directory is the Termux home directory.
3. Termux posts the exit status and bounded stdout/stderr in a `TERHUX_RESULT` comment, then closes the issue. The AI reads the comment through GitHub or GitHub MCP.

No JSON wrapper is needed for new requests. To work in a project, include `cd ~/project && ...` in the command. Each issue is a fresh shell, so working directory and shell variables do not persist between requests.

## Access and security

The repository is private. Grant **Triage** access only to AI accounts you fully trust: a Triage collaborator who can apply the queue label has remote shell access to the Termux user's files, tools, and credentials. The shell is intentionally unrestricted to behave like manual Termux; it is **not a security sandbox**. Never invite an untrusted agent and never put secrets in issue bodies or returned output.

GitHub Issues are the only active command/reply transport. The direct HTTP/Vercel relay files in the repository are experimental and are not started by the supervisor. Job commands/results/logs live under `~/.local/state/terhux`, outside the Git checkout. The worker never commits or pushes job data. Code updates use explicit `git fetch` followed by `git merge --ff-only FETCH_HEAD`; no `git pull` is used.

See [AI_BRIDGE.md](AI_BRIDGE.md) for the agent/MCP request format and [docs/PHONE_HOST_SETUP.md](docs/PHONE_HOST_SETUP.md) for the phone setup.

## Timeouts, delivery, and availability

- Default command timeout: 600 seconds; owner-configurable up to 1,800 seconds.
- Captured command output is bounded; the issue comment includes up to 30 KB. Long output is clipped in the comment.
- A timeout or output cap can leave partial side effects. Delivery is at least once: if Termux stops after a command has side effects but before it records the result, a retry may repeat it.
- Requests remain in GitHub while the phone is offline. The bridge works only while the phone is powered on, connected, and Android allows Termux to run. Termux:Boot and background/battery settings help, but no phone-based setup can guarantee availability when the phone or network is off.

This is a phone-hosted Termux environment, not an always-on GitHub VM.
