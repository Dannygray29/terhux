# Terhux client for GREY Chrome Bridge

This adds a small Termux-side CLI for the Android companion. It is **not automatic CapCut editing**: it can check the service, read visible non-editable labels, and ask for explicit confirmation before a tap or scroll. It does not submit forms or extract browser session data.

## Prerequisites
1. Install the debug APK from the bridge release path and open GREY Chrome Bridge.
2. Manually enable **GREY Chrome Bridge** in Android Accessibility Settings.
3. Keep the service active.
4. Run these commands from the Terhux repo directory in Termux:
   ```sh
   bash grey-chrome-bridge/terhux-client/setup-token.sh
   bash grey-chrome-bridge/terhux-client/bridge.sh status
   bash grey-chrome-bridge/terhux-client/bridge.sh screen
   ```
5. When prompted, paste the token shown in the app. Input is hidden. It is stored under `~/.config/grey-chrome-bridge/token` with owner-only permissions. Do not paste the token into chat, GitHub, or an issue.

## Commands
- `bash grey-chrome-bridge/terhux-client/bridge.sh status`
- `bash grey-chrome-bridge/terhux-client/bridge.sh screen`
- `bash grey-chrome-bridge/terhux-client/bridge.sh tap X Y` — requires typing `YES`
- `bash grey-chrome-bridge/terhux-client/bridge.sh scroll up` or `down` — requires typing `YES`

The service must be listening on `127.0.0.1:8765`. If status fails, check that the APK is installed and its accessibility service is manually enabled. The CLI has not been tested against a live device yet. A successful build does not prove CapCut control; the first real status/screen test must be run after installation.
