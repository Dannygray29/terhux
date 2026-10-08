# Terhux Claude Gateway

Claude can use GitHub's official remote MCP server to work with the Terhux repository. The repository now contains a GitHub Actions gateway that converts a structured Claude issue into the existing encrypted Terhux issue protocol.

## Flow

Claude -> GitHub MCP -> Claude-Terhux issue -> GitHub Actions -> encrypted issue -> Android Termux -> Terhux -> result.

The workflow requires the repository Actions secret `TERHUX_PIN`. The secret is never committed and is not exposed to Claude. GitHub Actions secrets are intended for sensitive workflow credentials. citeturn1search0turn1search2

**Authorization note:** this gateway automatically encrypts every matching issue with the Actions secret; Claude does not have to know or enter the PIN. Therefore, the practical authorization boundary for this gateway is who can open issues in the private repository (for example, Triage collaborators), not a per-request password prompt. Invite only agents trusted to submit actions. If every agent must be prompted for the PIN, use the direct client-side encrypted protocol in `AI_BRIDGE.md` instead of this automatic gateway.

The phone's public certificate must exist at `terhux-access-cert.pem`; the private key and PIN verifier remain under the phone's local `~/.config/terhux/`.

Claude should create issues with:

- title beginning with `[Claude-Terhux]`
- JSON body containing only the documented Terhux request fields
- `APPROVED` set to the string `true`

The gateway adds the `terhux-request` label only after successful encryption, preventing the phone worker from consuming the plaintext request.

## Claude connection

Use GitHub's official remote MCP server:

`https://api.githubcopilot.com/mcp/`

Claude custom connectors support remote MCP servers.
