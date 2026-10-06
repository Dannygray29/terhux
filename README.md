# Terhux

Terhux is a **single-input GitHub → Termux bridge**.

## Only input path

**Authorized AI → GitHub `commands/*.cmd` → Terhux → Termux → GitHub `results/*.result`**

The legacy raw shell inputs `COMMAND=`, `COMMAND_B64=`, and `WORKDIR=` are disabled.

Every request must use the structured format:

```
ACTION=<allowlisted action>
PROJECT=<registered project, when required>
PATH=<safe relative path, when required>
CONTENT_B64=<base64 content, when required>
APPROVED=true
```

Terhux never accepts an arbitrary shell command from the command file.

## Result

Results use the stable `TERHUX_RESULT_V1` format and are written to:

`results/<command-id>.result`

## Security

- Only allowlisted actions can execute.
- Arbitrary shell execution is disabled.
- Projects are registered explicitly.
- File paths must be relative and cannot traverse outside the project.
- Structured requests require `APPROVED=true`.
- Results are pushed back to GitHub automatically.

## Start

```
cd ~/terhux/repo
./terhux-supervisor.sh
```
