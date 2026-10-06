# Terhux

GitHub → Termux command bridge.

## Flow

ChatGPT/GitHub → `commands/` → Terhux background service → Termux → `results/`

## Command format

Structured commands use a small allowlisted protocol:

```
ACTION=node-version
APPROVED=true
```

No arbitrary shell commands are executed.

## Safe actions

- `pwd`
- `whoami`
- `date`
- `termux-version`
- `git-version`
- `node-version`
- `npm-version`
- `git-status`

## Folders

- `commands/` — commands waiting for Terhux
- `results/` — command results
- `status.txt` — bridge status
- `terhux-runner.sh` — command processor

The bridge is designed to be expanded with additional explicitly allowlisted actions and stronger approval/signing later.
