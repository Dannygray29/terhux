# Terhux AI Bridge Protocol

Terhux remains a transport bridge only. An AI client may use the GitHub repository to submit commands and read results.

## Submit a command

Create:
`commands/<id>.cmd`

Format:

```
COMMAND=echo hello
WORKDIR=/data/data/com.termux/files/home
APPROVED=true
```

For complex or multiline shell commands:

```
COMMAND_B64=<base64-encoded command>
WORKDIR=/data/data/com.termux/files/home
APPROVED=true
```

The AI client should use a unique command ID for every request.

## Read the result

After the Termux watcher processes the command, read:

`results/<id>.result`

A successful result has:

```
TERHUX_RESULT_V1
ID=<id>
STATUS=SUCCESS
EXIT_CODE=0
WORKDIR=<directory>
TIME=<unix timestamp>
STDOUT_BEGIN
<output>
STDOUT_END
STDERR_BEGIN
<errors>
STDERR_END
```

Other statuses are `ERROR` or `BLOCKED`.

## AI client rules

1. Never assume a command succeeded; read its result.
2. Treat non-zero `EXIT_CODE` as failure unless the requested command intentionally returns non-zero.
3. Do not submit commands without `APPROVED=true`.
4. Do not put secrets directly into command files when avoidable.
5. Do not add project-specific orchestration to Terhux. Project logic belongs in the AI client or the target project.
6. A command file is consumed and removed by the Termux runner after processing.

## Current verified transport

The complete path has been verified:

AI/GitHub command -> Terhux watcher -> Termux -> result -> GitHub.

Test result:

```
ID=watcher-test
STATUS=SUCCESS
EXIT_CODE=0
TERHUX_WATCHER_OK
```
