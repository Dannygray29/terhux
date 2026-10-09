# Direct Termux MCP server (replacement path)

This folder provides a small, provider-neutral MCP Streamable HTTP endpoint that runs on the Android phone. It removes GitHub Issues from the command/reply path.

## Tools

- `termux_status`: verify the phone-side server is alive.
- `termux_run`: run a command as the Termux owner, with a bounded timeout/output.
- `termux_read_file`: read a text file.
- `termux_list_files`: list a directory.

## Security model

This is remote shell access as the Termux user, not a sandbox. Anyone with the bearer token can execute commands and may access files, accounts, and project credentials available to that user. Keep the token private, use HTTPS only, and connect only trusted agents. Never commit the token to GitHub or paste it into prompts. The file tools keep their requested paths under the home directory, but the shell tool intentionally has the same power as the phone owner's shell.

The server binds to `127.0.0.1` by default. Do not bind it to `0.0.0.0` or expose port 8787 directly to the public internet.

## Start locally

Requirements: Node.js in Termux. Generate a strong secret locally and set `TERHUX_MCP_TOKEN` to it (32+ characters), then run:

```sh
node ~/terhux/repo/direct-mcp/server.mjs
```

The MCP endpoint is `http://127.0.0.1:8787/mcp`; local health check is `http://127.0.0.1:8787/health`.

## Remote access

A remote AI agent cannot reach `127.0.0.1` on the phone. A secure tunnel is required. Use a persistent authenticated tunnel (for example, a named Cloudflare Tunnel) pointing to `http://127.0.0.1:8787`. Store the tunnel credential locally on the phone, not in this repository. Do not use an ephemeral quick-tunnel URL as the permanent agent endpoint: it can change after restart.

The tunnel's stable HTTPS URL plus the bearer token are then configured in each MCP client that supports remote Streamable HTTP MCP and custom Authorization headers. Client authentication settings differ by provider; standard MCP protocol support alone does not mean every agent product supports the same auth configuration.

## Availability

The phone must be powered, connected, and Android must keep Termux running. Install the Termux:Boot add-on from the same trusted distribution as Termux and exempt Termux from battery optimization for reboot recovery. Android may still stop background work.

## Protocol note

This is a compact stateless JSON-RPC MCP endpoint intended for Streamable HTTP clients that accept JSON responses. It is not a general-purpose web server and exposes only the four declared tools.
