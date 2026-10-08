# Terhux AI Bridge

**Flow:** AI agent → GitHub Issue → Android Termux → GitHub Issue result → AI agent.

Any AI with a GitHub Issues connector or MCP server can use the bridge. The phone, not GitHub, runs the command.

## Access

The repository is private. Invite each trusted AI's GitHub account with **Triage** permission. Do not grant AI agents Write, Maintain, or Admin. Triage access to the issue queue is the authorization gate: any trusted Triage collaborator who can apply the `terhux-request` label can submit the documented actions. There is no per-request PIN prompt.

GitHub describes Triage as issue management without code-write access, and documents that users with Triage can apply labels: [repository roles](https://docs.github.com/organizations/managing-user-access-to-your-organizations-repositories/repository-roles-for-an-organization) and [managing labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels).

The phone worker only polls open issues carrying the `terhux-request` label. It also requires the title to start with `[Terhux]` and the body to be a valid JSON object. It never runs arbitrary shell text.

## Submit a request

Create an issue with:

- **Title:** begins with `[Terhux]`, followed by a short description.
- **Label:** `terhux-request`.
- **Body:** one JSON object only—no Markdown fences. All values must be strings. Include `APPROVED` with the string value `"true"`.

The worker creates the unique request ID from the GitHub issue number; do not include an `ID` field.

### Example JSON body

```json
{"ACTION":"terhux-runner-version","APPROVED":"true"}
```

### GitHub MCP example

GitHub's official MCP server supports issue creation and issue reads. With a connected GitHub MCP client, use its issue-write tool to create:

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

Then use the MCP issue-read tool with `method: "get_comments"` for that issue to receive the phone's result. Tool names vary among MCP clients; the operations needed are **create issue with a label** and **read issue comments**. The official GitHub remote MCP endpoint is `https://api.githubcopilot.com/mcp/`; the agent must authenticate with an account that has Triage access to this repository. See [GitHub's setup guide](https://docs.github.com/en/copilot/how-tos/copilot-in-your-ide/customize-copilot/extend-copilot-with-tools-and-context/set-up-the-github-mcp-server) and [official issue tool documentation](https://github.com/github/github-mcp-server).

### GitHub CLI example

```bash
gh issue create --repo Dannygray29/terhux \
  --title "[Terhux] Check runner version" \
  --label terhux-request \
  --body '{"ACTION":"terhux-runner-version","APPROVED":"true"}'
```

For other actions, put their documented parameters in the JSON body. Never include passwords, tokens, API keys, private keys, or other credentials.

## Supported actions

`PROJECT` names a directory under the phone owner's Termux home. `PATH` is relative to that directory; absolute paths and `..` traversal are rejected.

| Action | Required fields in addition to `ACTION` and `APPROVED` | Notes |
|---|---|---|
| `terhux-runner-version` | None | Harmless worker check. |
| `project-read-file` | `PROJECT`, `PATH` | Do not read or return secrets. |
| `project-write-file` | `PROJECT`, `PATH`, `CONTENT_B64` | `CONTENT_B64` is base64-encoded UTF-8 content. |
| `project-replace` | `PROJECT`, `PATH`, `FROM_B64`, `TO_B64` | Replaces one exact text match. |
| `project-install` | `PROJECT` | Runs `npm install`; package lifecycle scripts may execute. |
| `project-npm-install` | `PROJECT`, `PACKAGE` | Installs a development dependency; package scripts may execute. |
| `project-build` | `PROJECT` | Runs `npm run build`; project scripts may execute. |
| `project-test` | `PROJECT` | Runs `npm test`; project scripts may execute. |
| `project-android` | `PROJECT` | Runs `npm run android`; project scripts may execute. |
| `project-vercel-deploy` | `PROJECT` | Can publish/deploy; only trusted agents should request it. |
| `github-repo-rename` | `PROJECT`, `NEW_NAME` | Renames a repository; use only when authorized. |
| `terhux2-bootstrap` | None | Legacy bootstrap; avoid for ordinary requests. |

Unknown fields or malformed requests are rejected. `APPROVED="true"` is a request-format check, **not** a separate human approval checkpoint. A trusted Triage agent can submit a request that runs any action in this list.

## Results, retries, and availability

The phone polls labeled open issues about every five seconds. After an action, it commits `results/issue-<number>.result`, comments on the issue with the status and result link, and closes the issue. The AI should read the issue comments for the response; the result file is also available in the private repository.

Requests wait in GitHub while the phone is offline. Processing is sequential and best-effort. Delivery is at least once: if the phone stops after an external effect but before publishing the result, the request may be retried. Do not blindly resubmit after `TIMEOUT` or `OUTPUT_LIMIT`; inspect the issue and result first.

Project actions default to a 600-second wall-time limit (owner-configurable up to 1,800 seconds) and captured output is bounded. Timeouts can leave partial side effects. These limits are not an OS sandbox; deliberately detached processes may outlive the command. The bridge works only while the phone is powered on, connected, and allowing Termux to run.
