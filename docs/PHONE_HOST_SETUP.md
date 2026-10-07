
## Long-running actions and timeouts

Project build/test/install/deploy actions use a 600-second default wall-time limit. On timeout, the runner sends `TERM` to the command process group and escalates to `KILL` after five seconds. Captured output is capped (256 blocks by default) so a noisy loop cannot fill storage with logs. Results use `STATUS=TIMEOUT` or `STATUS=OUTPUT_LIMIT`; the phone worker then returns to polling the queue.

The phone owner may set `TERHUX_ACTION_TIMEOUT_SECONDS` before starting the supervisor, for example:

```bash
export TERHUX_ACTION_TIMEOUT_SECONDS=900
./terhux-start.sh
```

For reboot persistence, put the export in `~/.termux/boot/start-terhux` before the line that starts Terhux. Values are clamped to a maximum of 1,800 seconds; an AI request cannot change the limit. Install GNU coreutils (`pkg install coreutils`) so `timeout` is available. If `timeout` is missing, long-running actions fail closed instead of running unbounded.

A timeout cannot roll back changes already made by a project script or external service. Agents should inspect state before retrying a timed-out deploy, rename, build that writes files, or other side-effecting action.
