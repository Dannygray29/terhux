# Terhux Direct Remote Architecture

The direct bridge remains bound to localhost until a secure outbound relay is configured. Do not expose port 8787 directly to the public internet.

Target flow:
AI agent -> authenticated relay -> Termux Terhux direct bridge -> result -> relay -> AI agent

GitHub remains optional backup/control-plane storage, not the command transport.
