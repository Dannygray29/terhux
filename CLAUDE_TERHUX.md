# Terhux for Claude and MCP-connected agents

Claude and other AI agents can use Terhux through the private GitHub repository's Issues queue. The route is:

**AI/MCP client → GitHub Issue → phone running Termux → result comment → AI/MCP client.**

## One-time access

The repository owner invites the AI's GitHub account with **Triage** permission. The AI must connect an Issues-capable GitHub MCP server to that account. Triage access is the authorization gate; no password prompt or Actions secret is used. Only grant it to agents trusted to request the documented actions.

GitHub's official remote MCP endpoint is `https://api.githubcopilot.com/mcp/`. Its issue-write operation can create an issue with a label; its issue-read operation can fetch issue comments. See GitHub's [MCP setup guide](https://docs.github.com/en/copilot/how-tos/copilot-in-your-ide/customize-copilot/extend-copilot-with-tools-and-context/set-up-the-github-mcp-server) and [official MCP server](https://github.com/github/github-mcp-server). Other GitHub MCP clients work too if they can create labeled issues and read comments.

## Send a request

Create an issue in `Dannygray29/terhux`:

- Title starts with `[Terhux]`.
- Label is `terhux-request`.
- Body is one JSON object, no code fence; all values are strings and `APPROVED` is `"true"`.

Example MCP `issue_write` request:

```json
{
  "method": "create",
  "owner": "Dannygray29",
  "repo": "terhux",
  "title": "[Terhux] Check runner version",
  "body": "{\"ACTION\":\"terhux-runner-version\",\"APPROVED\":\"true\"}",
  "labels": ["terhux-request"]
}
```

The phone assigns an ID from the issue number, executes only an allowlisted action, then comments with the result and closes the issue. Read the issue comments with MCP `issue_read` using `method: "get_comments"`. For the accepted fields and actions, follow [AI_BRIDGE.md](AI_BRIDGE.md).

Do not submit passwords, API keys, tokens, or arbitrary shell commands. Requests can run only while the phone is online and Termux is active.
