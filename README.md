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
- project: `project-inspect`, `project-check`, `npm-test`, `npm-build`

There is still no arbitrary shell execution. File writes require explicit approval and are confined to registered projects.


## Result protocol

Results now begin with `TERHUX_RESULT_V1`. Stable key/value fields report the command, project, status, approval and exit code. STDOUT and STDERR use explicit delimiters so a controller can parse results reliably.


For multiline files, use `ACTION=file-write-b64` with `CONTENT_B64=<base64>`. This avoids newline/parsing problems in the command protocol.


### Development workflow

Use `project-inspect` before changing a project. It reports the registered root, current branch, Git status, a bounded file list, and package metadata. Then use the file and Git actions to make an approved change, followed by `npm-test` or `npm-build` and inspect the structured result before continuing.


`project-check` runs `npm test` and, only when tests pass, runs `npm run build`. A failure is returned with its exit code and captured output so the controller can decide the next change.


## Multi-project multitasking

Terhux now supports concurrent command workers.

- Default concurrency: **3 workers**
- Override with `TERHUX_WORKERS=N`
- Different registered projects can run at the same time.
- Tasks targeting the same project are serialized with a project lock to prevent conflicting file/Git operations.
- Commands are atomically claimed into `commands/.running/`, preventing two workers from processing the same task.
- GitHub result synchronization is protected by a global sync lock so concurrent workers do not race on Git.
- The existing approval gate and action allowlist remain active for every worker.
- There is still **no arbitrary shell execution**.

### Example

Three queued commands can run together:

```text
worker 1 → PROJECT=void       → npm-test
worker 2 → PROJECT=terhux     → project-inspect
worker 3 → PROJECT=greystudio → file-read
```

If two tasks target `void`, they wait for the `void` project lock instead of modifying the project simultaneously.

### Worker control

Run the watcher normally:

```bash
./terhux-watch.sh
```

Use four workers when the phone can handle it:

```bash
TERHUX_WORKERS=4 ./terhux-watch.sh
```

For a phone, the default of 3 is intentionally conservative. Build/test tasks can consume substantially more CPU and memory than inspection or file operations.


## Task manager

Use `terhux-task.sh` to create and inspect tasks without manually constructing command files.

```bash
./terhux-task.sh create void-check void project-inspect "" ""
./terhux-task.sh list
./terhux-task.sh status void-check
./terhux-task.sh cancel void-check
```

Task states are persisted in `tasks/*.state`:

`QUEUED → RUNNING → SUCCESS / ERROR / BLOCKED`

A queued task can be cancelled before a worker claims it. Running or completed tasks are not cancelled by this simple CLI.

The task manager is intentionally separate from command execution: it creates queue entries, while the multi-worker watcher schedules them.


## Controller interface

The controller wrapper provides a stable machine-facing entry point:

```bash
./terhux-controller.sh submit task-1 project-a project-inspect
./terhux-controller.sh approve task-1
./terhux-controller.sh status task-1
./terhux-controller.sh list
```

A submitted task starts in `APPROVAL=PENDING`. It does not enter the worker queue until explicitly approved. This is the boundary an AI controller can use: the controller may plan and submit work, while approval remains a separate operation.

## Multi-project AI workflow

The intended architecture is:

```text
AI agent/controller
       |
       v
Terhux controller
       |
       v
task queue
       |
   +---+---+
   |   |   |
 worker worker worker
   |   |   |
   A   B   C
```

The same Terhux worker pool can therefore service any registered projects. GitHub's own automation model also supports multiple jobs running concurrently and explicit concurrency controls, which is the same scheduling principle Terhux applies locally on Termux. citeturn0search0turn0search2
