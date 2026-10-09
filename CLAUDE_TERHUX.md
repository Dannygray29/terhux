# Terhux for Claude and MCP-connected agents

Terhux lets a trusted agent operate the owner's Termux shell through the private GitHub repository:

**AI/MCP client → GitHub Issue → phone running Termux → result comment → AI/MCP client.**

## Use it

Create an issue in `Dannygray29/terhux` with:

- A title starting with `[Terhux]`.
- The `terhux-request` label.
- The Bash command or script directly in the body—no JSON wrapper or code fence.

For example, use a body such as:

```bash
pwd
printf 'TERMUX_OK\n'
ls -la ~
```

For project work, include the directory change in the same command, e.g. `cd ~/project && npm test`. Each issue runs in a new login Bash from the Termux home directory, so `cd` and shell variables do not persist across issues.

The phone comments `TERHUX_STARTED:issue-N` when it picks up the request and `TERHUX_RESULT:issue-N` with the exit status and output when finished. Read the issue comments through GitHub MCP; the phone then closes the issue.

GitHub MCP tool names vary. Connect an Issues-capable GitHub MCP server to an account with **Triage** permission and use its issue-create operation with the label, then its issue-comments/read operation. GitHub's remote MCP endpoint is `https://api.githubcopilot.com/mcp/`; see its [setup guide](https://docs.github.com/en/copilot/how-tos/copilot-in-your-ide/customize-copilot/extend-copilot-with-tools-and-context/set-up-the-github-mcp-server).

## Access and execution limits

Triage access to this private repository is the authorization gate. **Treat it as full remote shell access to the Termux user's files, tools, and credentials.** Only the repository owner should grant it to trusted agents. The shell is intentionally unrestricted to behave like manual Termux; it is not an OS sandbox and there is no per-command human approval step. Do not request or print secrets.

Commands default to a 600-second wall-time limit (owner-configurable up to 1,800 seconds). Output is bounded and comments contain up to 30 KB. Requests remain queued while the phone is offline, but Termux must be running and connected for execution. Delivery is at least once; inspect an issue before resubmitting after a timeout.
