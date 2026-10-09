# Direct HTTP relay status

The separate direct HTTP/Vercel relay is **experimental and inactive**. It is not started by `terhux-supervisor.sh` and is not required for ordinary Terhux use.

Use the single active flow:

**AI agent → labeled GitHub Issue → Termux shell command → result comment → AI agent.**

GitHub Issues provide the durable mailbox; job data is never committed to the code repository. Do not expose the phone's local port or configure a relay URL. See [AI_BRIDGE.md](AI_BRIDGE.md) for the command and result-comment protocol.
