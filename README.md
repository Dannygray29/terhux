# Terhux

GitHub → Termux command bridge.

## Flow

ChatGPT/GitHub → `commands/` → Terhux background service → Termux → `results/`

## Command format

```
ACTION=git-status
PROJECT=void
APPROVED=true
```

No arbitrary shell commands are executed.

## Registered projects

- `terhux` → `~/terhux/repo`
- `void` → `~/void`

A project must be explicitly registered before Terhux can target it.

## Safe actions

- `pwd`
- `whoami`
- `date`
- `termux-version`
- `git-version`
- `node-version`
- `npm-version`
- `project-list`
- `git-status` + PROJECT
- `git-branch` + PROJECT
- `npm-test` + PROJECT
- `npm-build` + PROJECT

The bridge is designed to be expanded with additional explicitly allowlisted projects and actions.
