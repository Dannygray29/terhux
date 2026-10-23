# Mandatory Terhux Operator Rules

These rules apply to every AI agent using Terhux. They are mandatory workflow constraints, not optional style suggestions.

## Work silently until the task is actually complete

1. **Do not send progress updates, status narration, percentages, or interim summaries.** Keep working and verify until the requested task is complete.
2. **Submit one Terhux issue at a time.** Wait for both `TERHUX_STARTED:issue-N` and the matching final `TERHUX_RESULT:issue-N` before submitting the next command. A start marker is not completion.
3. **On an error, diagnose and repair it, then continue.** Do not stop at the first recoverable failure, report the error as the final answer, or ask the user to run routine follow-up commands when the agent can safely fix it through Terhux.
4. After each repair, rerun the failed check and the relevant regression tests. Continue through the remaining checklist, including independent checks that do not depend on the failed step.
5. Preserve user data, local uncommitted work, secrets, and safety backups. Never use destructive resets, broad deletes, or secret-printing commands as a shortcut. If a step risks irreversible data loss or requires a decision only the user can make, stop that specific action and explain the blocker in the final response.
6. Keep actions idempotent where possible. Because issue delivery is at-least-once, inspect the issue and local state before retrying a command that may already have changed something.
7. Verify the final state from command output and tests. Never claim a fix, deployment, sync, or cleanup succeeded solely because a command was submitted or a start marker appeared.
8. Return to the user **only when the requested task is done**, with a concise final report of verified changes, tests, and any genuine remaining blocker. If something cannot be completed safely or the phone/bridge is unavailable, report that limitation truthfully rather than pretending completion.

## Required execution loop

For each task:

- Submit one labeled `terhux-request` issue with a `TERHUX-SHELL-V1` body.
- Poll/read comments until the matching `TERHUX_RESULT:issue-N` arrives.
- Inspect exit code and output; diagnose any failure.
- Fix the cause, then rerun the failing check.
- Continue the remaining work without progress narration.
- Run final syntax, regression, state/secret-safety, and service checks relevant to the change.
- Only then send one final user-facing response.

These rules govern the AI operator's behavior. Terhux's worker already serializes issue processing within the phone bridge; the AI must also serialize submissions and wait for final results.
