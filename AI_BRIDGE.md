# Terhux AI Bridge Protocol

Terhux runs on the owner's Android phone inside Termux. GitHub Issues are the request queue; the phone is the only execution host. Knowing the repository URL does not grant access.

## Access requirements

- The AI account must be invited to the private repository with **Triage** permission. Triage can create/comment on issues but cannot push runner code. Do **not** grant AI agents Write, Maintain, or Admin access.
- The phone owner initializes a local access PIN and key pair with `bash terhux-auth-init.sh`. The phone stores its private key and a scrypt PIN verifier outside the repository in `~/.config/terhux/`; only the public certificate is committed as `terhux-access-cert.pem`.
- A replacement phone that has the repository's public certificate but lacks the matching local private key must be initialized with `bash terhux-auth-init.sh --rotate`; this replaces the public certificate and invalidates requests encrypted to the old one.
- If the AI does not have the PIN in its approved secret store, it must ask the owner privately. **Never put the PIN in an issue, repository file, or commit.** Do not paste the PIN into a public or shared channel.

The phone wraps each request and PIN in an authenticated CMS AES-256-GCM envelope encrypted to the phone's public certificate. GitHub issue bodies contain only that ciphertext. The PIN is checked locally; failed attempts are rate-limited to 5 per GitHub identity and 20 total per rolling 24 hours. Short PINs remain weak against online guessing; use a longer random PIN.

## Submit a request

Create a JSON file containing only structured request fields. Values must be strings. Use a unique `ID` of 1–80 letters, digits, dots, underscores, or hyphens, and include `APPROVED` set to the string `true`.

Example health/version request (`request.json`):

```json
{"ID":"health-20261007-a1","ACTION":"terhux-runner-version","APPROVED":"true"}
```

Example file read:

```json
{"ID":"read-20261007-b2","ACTION":"project-read-file","PROJECT":"netboost","PATH":"README.md","APPROVED":"true"}
```

Example file write (base64-encode the UTF-8 file contents):

```json
{"ID":"write-20261007-c3","ACTION":"project-write-file","PROJECT":"netboost","PATH":"notes/agent.txt","CONTENT_B64":"<base64-content>","APPROVED":"true"}
```

Use the repository's public helper to encrypt the request. `TERHUX_PIN` must come from the AI platform's protected secret store or from a private owner prompt; do not hard-code it in source or shell history.

```bash
node terhux-encrypt-request.js request.json > encrypted-body.txt
gh issue create --repo Dannygray29/terhux \
  --title "[Terhux] health-20261007-a1" \
  --label terhux-request \
  --body-file encrypted-body.txt
rm -f encrypted-body.txt
```

The issue body must be the helper output, exactly as generated (`TERHUX_CMS_V1` and `PAYLOAD_B64=...`). Do not wrap it in Markdown fences or add plaintext request fields. The helper needs Node.js, OpenSSL 3.x, and the repository's current public certificate. It does not print the PIN or write plaintext to a file; it streams the payload to OpenSSL through stdin and emits only ciphertext.

If the PIN is not available, ask the owner through a private channel. If a request is unsigned/malformed or has the wrong PIN, the phone does **not** execute it; it comments with a safe error and removes the request label. After receiving the PIN, create a fresh request with a new unique ID. Never retry an action under an ID whose result already exists.

## Allowed actions

`PROJECT` names a directory under the phone owner's Termux home. `PATH` is relative to that directory; absolute paths and `..` traversal are rejected.

| Action | Required fields | Notes |
|---|---|---|
| `terhux-runner-version` | `ID`, `ACTION`, `APPROVED` | Harmless worker check. |
| `project-read-file` | plus `PROJECT`, `PATH` | Do not read or return secrets. |
| `project-write-file` | plus `PROJECT`, `PATH`, `CONTENT_B64` | Writes a project file. |
| `project-replace` | plus `PROJECT`, `PATH`, `FROM_B64`, `TO_B64` | Replaces one exact text match. |
| `project-install` | plus `PROJECT` | Runs `npm install`; lifecycle scripts may execute. |
| `project-npm-install` | plus `PROJECT`, `PACKAGE` | Installs a development dependency; package scripts may execute. |
| `project-build` | plus `PROJECT` | Runs `npm run build`; project scripts may execute. |
| `project-test` | plus `PROJECT` | Runs `npm test`; project scripts may execute. |
| `project-android` | plus `PROJECT` | Runs `npm run android`; project scripts may execute. |
| `project-vercel-deploy` | plus `PROJECT` | Can publish/deploy; use only with owner authorization. |
| `github-repo-rename` | plus `PROJECT`, `NEW_NAME` | Renames a repository; use only with owner authorization. |
| `terhux2-bootstrap` | `ID`, `ACTION`, `APPROVED` | Legacy service bootstrap; avoid for ordinary requests. |

There is no arbitrary shell-command action. `APPROVED=true` is a request-format check, **not** a separate human approval checkpoint. Only request work the owner has authorized.

## Results and limits

The phone polls labeled open issues about every five seconds. An issue waits while the phone is offline. After processing, the phone commits `results/<ID>.result`, comments on the issue with the status and result link, then closes the issue. If PIN setup is missing or authentication fails, the issue stays open without the queue label until a new encrypted request is submitted.

A successful result contains `STATUS=SUCCESS` and `EXIT_CODE=0`. Other statuses include `ERROR`, `BLOCKED`, `TIMEOUT`, and `OUTPUT_LIMIT`. Long-running project actions default to a 600-second limit (owner-configurable to at most 1,800 seconds); captured output is bounded. Timeouts can leave partial side effects—inspect before retrying. These limits are not a sandbox; deliberately detached project processes may outlive the command.

Issue processing is sequential and best-effort. The bridge is available only when the phone, Termux, GitHub credentials, and network are working. It is not a GitHub-hosted VM and cannot execute while the phone is off.

## Security rules

1. Use a unique ID and only the documented action allowlist.
2. Never place the PIN, tokens, private keys, or credentials in an issue or repository file.
3. Do not submit raw shell commands or arbitrary code.
4. Only access project files and external services the owner has authorized.
5. Never grant the AI account code-write permissions on the execution repository.
6. A completed action may have partial external effects; do not blindly resubmit after `TIMEOUT` or `OUTPUT_LIMIT`.
