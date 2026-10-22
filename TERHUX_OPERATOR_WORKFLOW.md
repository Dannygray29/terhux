# Terhux Operator Workflow — Standing User Preference

This is the user's required default workflow for work performed through Terhux/Tawks.

1. Operate serially: issue one task/command, then wait until Terhux has posted BOTH `TERHUX_STARTED:issue-N` and `TERHUX_RESULT:issue-N` (including its final status/output).
2. Do not queue a dependent task before the previous task's result has arrived.
3. Once a task result arrives, continue autonomously: immediately issue the next logical Terhux command and run it. Repeat the wait-for-result cycle.
4. Do not send the user routine progress messages, acknowledgements, or narration between tasks. Keep working through Terhux.
5. Return to the user only when there is an actual error/blocker requiring their input, or a genuinely important project recommendation/decision to communicate.
6. Never claim a task succeeded until Terhux reports the result and relevant checks support it. If blocked, state the exact blocker and the minimum needed next action.
7. Keep credentials, API keys, passwords, wallet secrets, and other sensitive values out of GitHub issue bodies/comments and logs. Redact secrets from diagnostics.
8. Preserve existing project files and behavior unless the requested task requires a change. Prefer small, verified, reversible changes.
9. This workflow applies to future Terhux work unless the user explicitly changes it.

Operational shorthand: **queue → wait for STARTED and RESULT → verify → queue next; no interim chat updates.**
