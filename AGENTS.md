# Mandatory Terhux Operator Rules

**BOOTSTRAP REQUIREMENT — READ THIS FILE BEFORE EVERY TERHUX TASK.** The AI operator must fetch the current `AGENTS.md` from `Dannygray29/terhux` at the beginning of every new Terhux work session and whenever a task is resumed after context loss. Treat these rules as binding. Before submitting any `terhux-request`, include the compact rule block below in the operator's active task context; do not assume prior chat memory is sufficient. Never submit a dependent issue until the previous issue has a matching final `TERHUX_RESULT:issue-N`.

## Always-on compact rule block

- One task at a time; wait for `TERHUX_STARTED:issue-N` **and** matching `TERHUX_RESULT:issue-N` before the next dependent command.
- No progress/status narration, empty updates, time-spent notices, or percentages unless the user explicitly asks.
- If a recoverable error occurs, diagnose it, repair it, rerun the failed check, and continue. Do not stop after reporting the error.
- Keep working silently through Terhux/GitHub until verified completion or a genuine blocker requiring the user's decision.
- Preserve unrelated projects, user data, local uncommitted changes, secrets, and backups. Avoid destructive resets and broad deletes.
- Verify outcomes from actual output and tests. Never claim success from task submission or a start marker alone.
- Final response only when done or genuinely blocked; concise, truthful, and based on verified results.

## Mandatory detailed rules

These rules apply to every AI agent using Terhux. They are mandatory workflow constraints, not optional style suggestions.

### Work silently until the task is actually complete

1. **Do not send progress updates, status narration, percentages, or interim summaries.** Keep working and verify until the requested task is complete. Exception: percentages only when the user explicitly asks.
2. **Submit one Terhux issue at a time.** Wait for both `TERHUX_STARTED:issue-N` and the matching final `TERHUX_RESULT:issue-N` before submitting the next dependent command. A start marker is not completion.
3. **On an error, diagnose and repair it, then continue.** Do not stop at the first recoverable failure, report the error as the final answer, or ask the user to run routine follow-up commands when the agent can safely fix it through Terhux.
4. After each repair, rerun the failed check and the relevant regression tests. Continue through the remaining checklist, including independent checks that do not depend on the failed step.
5. Preserve user data, local uncommitted work, secrets, and safety backups. Never use destructive resets, broad deletes, or secret-printing commands as a shortcut. If a step risks irreversible data loss or requires a decision only the user can make, stop that specific action and explain the blocker in the final response.
6. Keep actions idempotent where possible. Because issue delivery is at-least-once, inspect the issue and local state before retrying a command that may already have changed something.
7. Verify the final state from command output and tests. Never claim a fix, deployment, sync, or cleanup succeeded solely because a command was submitted or a start marker appeared.
8. Return to the user **only when the requested task is done**, with a concise final report of verified changes, tests, and any genuine remaining blocker. If something cannot be completed safely or the phone/bridge is unavailable, report that limitation truthfully rather than pretending completion.

## Required execution loop

For each task:

- Read this file at the start of the work session and re-read it after context loss.
- Submit one labeled `terhux-request` issue with a `TERHUX-SHELL-V1` body.
- Poll/read comments until the matching `TERHUX_RESULT:issue-N` arrives.
- Inspect exit code and output; diagnose any failure.
- Fix the cause, then rerun the failing check.
- Continue the remaining work without progress narration.
- Run final syntax, regression, state/secret-safety, and service checks relevant to the change.
- Only then send one final user-facing response.

These rules govern the AI operator's behavior. Terhux's worker serializes issue processing within the phone bridge; the AI must also serialize submissions and wait for final results. The rules are now duplicated in a compact block so they can be surfaced at the start of each task without relying on old conversation context.