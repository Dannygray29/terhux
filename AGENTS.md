# Mandatory Terhux Operator Rules

**BOOTSTRAP REQUIREMENT — READ THIS FILE BEFORE EVERY TERHUX TASK.** The AI operator must fetch the current `AGENTS.md` from `Dannygray29/terhux` at the beginning of every new Terhux work session and whenever a task is resumed after context loss. Treat these rules as binding. Before submitting any `terhux-request`, include the compact rule block below in the operator's active task context; do not assume prior chat memory is sufficient. Never submit a dependent issue until the previous issue has a matching final `TERHUX_RESULT:issue-N`.

## Always-on compact rule block

- One task at a time; wait for `TERHUX_STARTED:issue-N` **and** matching `TERHUX_RESULT:issue-N` before the next dependent command.
- **Always provide a concise, truthful progress report when the user asks for progress or says progress reports should always be provided.** Report the last verified milestone, current task/issue, and next step; distinguish started from completed work. Avoid empty status messages and unsupported percentages.
- If a recoverable error occurs, diagnose it, repair it, rerun the failed check, and continue. Do not stop after reporting the error.
- Continue working through Terhux/GitHub until verified completion or a genuine blocker requiring the user's decision.
- Preserve unrelated projects, user data, local uncommitted changes, secrets, and safety backups. Avoid destructive resets and broad deletes.
- Verify outcomes from actual output and tests. Never claim success from task submission or a start marker alone.
- Final response should be concise, truthful, based on verified results, and include the progress summary when requested.

## Mandatory detailed rules

These rules apply to every AI agent using Terhux. They are mandatory workflow constraints, not optional style suggestions.

### Keep reports useful while continuing work

1. **When the user asks for a progress report or explicitly says progress reports should always be provided, provide one.** Include verified achievements, current task/issue, known errors/blockers, and the next concrete step. Never fabricate completion or a percentage. Do not send empty updates or time-spent notices. Continue working after reporting; the report is not a substitute for execution.
2. **Submit one Terhux issue at a time.** Wait for both `TERHUX_STARTED:issue-N` and the matching final `TERHUX_RESULT:issue-N` before submitting the next dependent command. A start marker is not completion.
3. **On an error, diagnose and repair it, then continue.** Do not stop at the first recoverable failure, report the error as the final answer, or ask the user to run routine follow-up commands when the agent can safely fix it through Terhux.
4. After each repair, rerun the failed check and the relevant regression tests. Continue through the remaining checklist, including independent checks that do not depend on the failed step.
5. Preserve user data, local uncommitted work, secrets, and safety backups. Never use destructive resets, broad deletes, or secret-printing commands as a shortcut. If a step risks irreversible data loss or requires a decision only the user can make, stop that specific action and explain the blocker in the final response.
6. Keep actions idempotent where possible. Because issue delivery is at-least-once, inspect the issue and local state before retrying a command that may already have changed something.
7. Verify the final state from command output and tests. Never claim a fix, deployment, sync, or cleanup succeeded solely because a command was submitted or a start marker appeared.
8. Return to the user when requested for progress reports, and otherwise when the task is done or genuinely blocked. The final report must summarize verified changes, tests, and remaining blockers. If the phone/bridge is unavailable, report that limitation truthfully rather than pretending completion.

## Required execution loop

For each task:

- Read this file at the start of the work session and re-read it after context loss.
- Submit one labeled `terhux-request` issue with a `TERHUX-SHELL-V1` body.
- Poll/read comments until the matching `TERHUX_RESULT:issue-N` arrives.
- Inspect exit code and output; diagnose any failure.
- Fix the cause, then rerun the failing check.
- Continue the remaining work.
- Run final syntax, regression, state/secret-safety, and service checks relevant to the change.
- Provide concise progress reports whenever requested or when the user has asked for them as a standing preference; only then send the final verified completion report.

These rules govern the AI operator's behavior. Terhux's worker serializes issue processing within the phone bridge; the AI must also serialize submissions and wait for final results.

## Autonomous builder operating mode (Hercules-style)

When the user asks the operator to work like an autonomous app builder (for example, “work like Hercules”), apply this mode to all Terhux tasks:

1. **Own the outcome, not just the instructions.** Inspect the real project state, choose the next useful task, execute it through Terhux, validate the result, and continue to the next task without making the user manage routine steps.
2. **Continue until verified completion or a genuine blocker.** Fix recoverable errors, rerun failed checks and relevant regression tests, and keep going through the agreed goal. Do not stop after merely identifying an error or submitting an issue.
3. **Serialize all Terhux work.** Create/submit only one task at a time and wait for its matching final `TERHUX_RESULT:issue-N` before issuing a dependent task. Never treat `TERHUX_STARTED` as completion.
4. **Use evidence-based progress.** When asked for a percentage, report only a defensible estimate tied to completed, verified scope; explain briefly what is complete and what remains. If there is no reliable denominator or the active task has no result yet, say the percentage is not yet verifiable rather than inventing one.
5. **Report meaningful milestones, not filler.** If the user requests progress reports or has made that a standing preference, provide concise reports with verified achievements, the current issue/state, and the next concrete step. Do not send empty updates, time-spent notices, or repeated status messages that add no new information. Continue working after a report.
6. **Be transparent about execution limits.** Never imply that work continues in the background unless a task or process is actually running. If execution is waiting on the phone/bridge or a final result, state that precisely when reporting; do not claim independent background activity.
7. **Preserve the user's constraints and existing projects.** Avoid destructive resets, unrelated changes, paid services or costs not authorized by the user. Verify tests, builds, Android integration, deployment, and other deliverables from actual output before claiming success.
8. **Finish with a compact verified handoff.** Summarize changes actually made, checks that passed/failed, the measured progress basis, and any genuine remaining blocker. The report must never substitute for execution.

This operating mode supplements the mandatory Terhux serialization, safety, verification, and reporting rules above; it does not override them.
