# Terhux AI Bridge

**Flow:** AI agent → labeled GitHub Issue → Termux shell → result comment → AI agent.

GitHub Issues are the mailbox. The AI does not ask the phone owner to relay commands: it submits the command through GitHub/MCP, waits for Termux's comments, and reads the result.

## Access and security

The repository is private. Give **Triage** access only to AI accounts you fully trust. A Triage collaborator who can add `terhux-request` has remote shell access to the Termux user's files, programs, and credentials. This is intentionally equivalent to letting that agent use the phone's Termux manually. It is **not a security sandbox** and there is no per-command human approval step.

Do not invite untrusted agents. Never put passwords, tokens, private keys, or other secrets in an issue body or ask the shell to print them into an issue comment. The active bridge uses GitHub Issues only; no PIN, Actions secret, Vercel relay, or public phone port is required.

## Send a command

Create an issue in `Dannygray29/terhux`:

- **Title:** starts with `[Terhux]`, e.g. `[Terhux] Check Termux environment`.
- **Label:** `terhux-request`.
- **Body:** the shell command or multi-line Bash script itself—no JSON wrapper and no Markdown fence.

Example body:

```bash
pwd
printf 'TERMUX_OK\n'
ls -la ~
```

To work in a project, include the directory change in the same request, for example:

```bash
cd ~/my-project && npm test
```

Each issue runs in a **fresh login Bash** starting in the Termux home directory. `cd`, shell variables, and other interactive state do not persist between issues; include setup commands in each request as needed. Requests are limited to 32 KB.

### Using a GitHub MCP server

Use the connected GitHub MCP client's issue-create operation with:

```json
{
  "owner": "Dannygray29",
  "repo": "terhux",
  "title": "[Terhux] Check Termux environment",
  "body": "pwd\nprintf 'TERMUX_OK\\n'\nls -la ~",
  "labels": ["terhux-request"]
}
```

Then read that issue's comments. MCP tool names/argument shapes vary by client; the required operations are **create issue with a label** and **read issue comments**. GitHub's remote MCP endpoint is `https://api.githubcopilot.com/mcp/`; authenticate the MCP client with an account granted Triage access. See GitHub's [MCP setup guide](https://docs.github.com/en/copilot/how-tos/copilot-in-your-ide/customize-copilot/extend-copilot-with-tools-and-context/set-up-the-github-mcp-server) and [official GitHub MCP server](https://github.com/github/github-mcp-server).

## Read the response

The phone posts:

1. `TERHUX_STARTED:issue-N` when it accepts the command.
2. `TERHUX_RESULT:issue-N` with the exit status and captured output when it finishes, then closes the issue.

If there is no `TERHUX_STARTED` comment, the phone has not visibly picked up the issue. If it is started but no result arrives, the command may still be running or the phone/network may have stopped; check the issue before resubmitting.

## Timeouts and reliability

- Default wall-time limit is 600 seconds; the owner may set it up to 1,800 seconds. The AI cannot raise it in a request.
- Command output is bounded at the Termux runner and the issue comment includes up to 30 KB; larger output is clipped.
- Requests wait in GitHub while the phone is offline. The phone polls about every five seconds by default.
- Delivery is **at least once**, not exactly once. If the phone stops after a command has side effects but before it saves/posts its result, the command may be retried. Check the issue before resubmitting after a timeout.
- Job commands/results are stored under `~/.local/state/terhux`, outside the Git checkout. The worker does not commit or push job data. Updates use explicit `git fetch` and `git merge --ff-only FETCH_HEAD`; the bridge never uses `git pull` for its own updates.

The loop works only while the phone is powered on, online, and Android allows Termux to run. Termux:Boot/background settings help it resume after a reboot, but cannot guarantee service when the phone or network is off.

### Compatibility

Already-queued legacy diagnostic JSON requests such as `{"ACTION":"terhux-runner-version","APPROVED":"true"}` remain supported. Old project-specific structured actions are retired; new agent requests should use the raw shell body above.
