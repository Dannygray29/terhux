# Terhux

GitHub → Termux command bridge.

## Command format

```
ACTION=file-read
PROJECT=void
PATH=package.json
APPROVED=true
```

For a write:

```
ACTION=file-write
PROJECT=void
PATH=src/example.txt
CONTENT=hello
APPROVED=true
```

File paths are restricted to registered project directories and must be relative. Parent-directory traversal is blocked.

## Registered projects

- `terhux` → `~/terhux/repo`
- `void` → `~/void`

## Safe actions

- system: `pwd`, `whoami`, `date`, `termux-version`, `git-version`
- development: `node-version`, `npm-version`, `project-list`
- Git: `git-status`, `git-branch`, `git-diff`, `git-add`, `git-commit`, `git-push`
- files: `file-list`, `file-read`, `file-write`
- project: `npm-test`, `npm-build`

There is still no arbitrary shell execution. File writes require explicit approval and are confined to registered projects.


## Result protocol

Results now begin with `TERHUX_RESULT_V1`. Stable key/value fields report the command, project, status, approval and exit code. STDOUT and STDERR use explicit delimiters so a controller can parse results reliably.


For multiline files, use `ACTION=file-write-b64` with `CONTENT_B64=<base64>`. This avoids newline/parsing problems in the command protocol.
