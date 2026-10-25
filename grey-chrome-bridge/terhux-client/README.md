# Terhux client for GREY Chrome Bridge

The goal is **one-tap connection after initial Android permissions**. This is visible-UI control only, not automatic CapCut editing.

## First-time setup
1. Install and open GREY Chrome Bridge.
2. Manually enable its Accessibility Service in Android Accessibility Settings. Android does not allow apps to grant this permission themselves.
3. In Termux, enable **Allow external apps to run commands** in Termux settings. This is required for the app's **Connect to Terhux** button.
4. Ensure the repository is at `~/terhux/repo` and the client file exists at `~/terhux/repo/grey-chrome-bridge/terhux-client/receive-token.sh`.
5. Return to GREY Chrome Bridge and tap **Connect to Terhux**. It transfers the random token locally to Termux and stores it in `~/.config/grey-chrome-bridge/token` with owner-only permissions. No copying, typing, or sending the token to chat is required.
6. In Termux, verify with:
   ```sh
   bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh status
   bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh screen
   ```

## Commands
- `bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh status`
- `bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh screen`
- `bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh tap X Y` — asks for confirmation
- `bash ~/terhux/repo/grey-chrome-bridge/terhux-client/bridge.sh scroll up|down` — asks for confirmation

The service listens only on `127.0.0.1:8765`. The token stays on-device. The APK and live-device connection have not yet been tested on the user's phone. A successful build does not prove CapCut control; verify the status/screen commands after installation.
