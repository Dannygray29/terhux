# Terhux

Terhux is a **simple GitHub → Termux bridge**.

It does one thing:

**receive a command → execute it in Termux → return the result.**

## Command

Create a file in `commands/`:

```
COMMAND=echo hello
WORKDIR=~/my-project
APPROVED=true
```

For multiline or complex commands, use base64:

```
COMMAND_B64=<base64 command>
WORKDIR=~/my-project
APPROVED=true
```

The bridge polls GitHub every few seconds, executes the command, and writes:

`results/<command-id>.result`

## Result

Results use:

```
TERHUX_RESULT_V1
ID=...
STATUS=SUCCESS
EXIT_CODE=0
WORKDIR=...
STDOUT_BEGIN
...
STDOUT_END
STDERR_BEGIN
...
STDERR_END
```

## Start

```
cd ~/terhux/repo
chmod +x terhux-runner.sh terhux-watch.sh
./terhux-supervisor.sh
```

The supervisor starts one simple watcher. There are no workers, task managers, project registries, schedulers, or project-specific actions.

## Security

Every command must explicitly contain `APPROVED=true`. Termux also provides its own Android-side security controls for third-party command execution through `RUN_COMMAND`; those controls are separate from this GitHub transport. See the official Termux documentation for that mechanism. 
