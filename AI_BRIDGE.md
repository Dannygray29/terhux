# Terhux AI Bridge Protocol

# Terhux's worker runs on the owner's Android phone inside Termux. GitHub is only the shared request/result channel. An AI agent needs authorized access to this private repository; it does not get a Linux session merely by knowing the repository URL.

## Submit a request

Create a uniquely named file at `commands/<id>.cmd` on the repository's `main` branch. Use a filename ID containing only letters, digits, dots, underscores, or hyphens. Each request must use the structured fields below; do not send raw shell commands.

Example health/version request:

```text
ACTION=terhux-runner-version
APPROVED=true
```

Example file read:

```text
ACTION=project-read-file
PROJECT=netboost
PATH=README.md
APPROVED=true
```

Example file write (base64-encode the UTF-8 file contents):

```text
ACTION=project-write-file
PROJECT=netboost
PATH=notes/agent.txt
CONTENT_B64=<base64-encoded-content>
APPROVED=true
```

`PROJECT` names a directory under the Termux home directory. `PATH` is relative to that project directory. Do not use absolute paths or `..` path traversal. The runner currently supports these action names:

| Action | Required fields | Notes |
|---|---|---|
| `terhux-runner-version` | none | Harmless check that the phone worker processed a request. |
| `project-read-file` | `PROJECT`, `PATH` | Reads a project file into the result. Do not read or return secrets. |
| `project-write-file` | `PROJECT`, `PATH`, `CONTENT_B64` | Writes a project file. |
| `project-replace` | `PROJECT`, `PATH`, `FROM_B64`, `TO_B64` | Replaces one exact text match in a project file. |
| `project-install` | `PROJECT` | Runs `npm install` in the project. Dependency lifecycle scripts may execute. |
| `project-npm-install` | `PROJECT`, `PACKAGE` | Installs a package as a development dependency; package scripts may execute. |
| `project-build` | `PROJECT` | Runs `npm run build`; project scripts may execute. |
| `project-test` | `PROJECT` | Runs `npm test`; project scripts may execute. |
| `project-android` | `PROJECT` | Runs `npm run android`; project scripts may execute. |
| `project-vercel-deploy` | `PROJECT` | Can publish/deploy the project; use only when the owner has authorized that deployment. |
| `github-repo-rename` | `PROJECT`, `NEW_NAME` | Renames a GitHub repository; use only when the owner has authorized the change. |
| `terhux2-bootstrap` | none | Legacy Termux service bootstrap action; do not use for ordinary requests. |

`APPROVED=true` is required by the runner but is **not** a human approval checkpoint. A request from an authorized writer can run without another person reviewing it. Build/install actions execute code from the project, and deploy/rename actions have external effects. Only give write access to trusted agents.

## Read the result

The phone polls the `main` branch about every five seconds by default. Requests committed while the phone is offline remain queued in GitHub. Once processed, the request file is consumed and the result is committed at `results/<id>.result`. If a push fails, the phone now retains local request/result changes and retries synchronization on later watcher cycles rather than hard-resetting them away. Read the result from GitHub and check `STATUS` and `EXIT_CODE`; never assume success from a notification alone.

Delivery is **at least once**, not exactly once. If the phone or process stops after an action takes effect but before its result/acknowledgement is safely published, the request may be attempted again after recovery. Agents should prefer idempotent work and check for an existing effect before retrying requests that deploy, rename, or otherwise change external state.

A successful response uses this format:

```text
TERHUX_RESULT_V1
ID=<id>
ACTION=<action>
PROJECT=<project>
PATH=<path>
APPROVED=true
STATUS=SUCCESS
EXIT_CODE=0
TIME=<unix timestamp>
STDOUT_BEGIN
<output>
STDOUT_END
STDERR_BEGIN
<errors>
STDERR_END
```

Other statuses include `ERROR` and `BLOCKED`. If the result does not arrive, the phone may be offline, Termux may have been suspended/stopped, or the worker may lack GitHub connectivity/credentials. GitHub does not host a spare always-on worker.

## Security and availability rules for agents

1. Use a unique request ID and only the documented `ACTION=` protocol.
2. Never send `COMMAND=`, `COMMAND_B64=`, or arbitrary shell code; the legacy raw-shell protocol is disabled.
3. Do not place credentials, tokens, private keys, or other secrets in request files or results.
4. Only read or modify files that the task owner has authorized.
5. Use deploy/rename actions only with the owner's explicit authorization.
6. A result is available only when the phone and Termux bridge are online and able to reach GitHub.

Historical transport test from the repository:

```
ID=watcher-test
STATUS=SUCCESS
EXIT_CODE=0
TERHUX_WATCHER_OK
```
