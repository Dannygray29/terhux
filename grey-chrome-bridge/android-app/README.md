# GREY Chrome Bridge Android companion (prototype)

This is an **opt-in Android AccessibilityService prototype** intended to let Terhux inspect visible UI labels and issue deliberate taps/scrolls in the foreground app, including Chrome with CapCut open. It does not automate editing steps by itself and does not expose the page DOM.

## Build

A GitHub Actions workflow builds a debug APK:
1. Open the repository's **Actions** tab.
2. Select **Build GREY Chrome Bridge APK**.
3. Run **Run workflow** on `feat/grey-chrome-accessibility-bridge`, or let the workflow run after a matching source change.
4. Download the `grey-chrome-bridge-debug-apk` artifact from the successful run. Artifacts expire after 14 days.

The Android SDK is not installed in the phone's Termux environment, so the APK has not been built or installed locally.

## Install and enable on Android 15

1. Download the APK artifact and extract it.
2. Open the APK on the phone and approve Android's install prompt for the source you chose, if asked.
3. Open **GREY Chrome Bridge**.
4. Tap **Open Accessibility Settings**.
5. Find **GREY Chrome Bridge** and manually enable it. Review Android's accessibility warning and only proceed if you accept the stated scope.
6. Return to the app. It displays a random local control token. Treat it like a password; do not post it in GitHub issues, chats, or logs.
7. Keep the app/service running while testing.

## Local API

The service binds only to `127.0.0.1:8765`. Requests require the `X-Grey-Token` header using the token shown inside the companion app.

- `GET /health` — service status.
- `GET /windows` — foreground package and visible accessibility labels; editable and password fields are excluded.
- `POST /tap?x=PIXEL&y=PIXEL` — sends a tap gesture.
- `POST /scroll?direction=up` or `direction=down` — scroll gesture.

Example (replace the placeholder locally; never put the actual token into shell history or GitHub):
```sh
curl -H 'X-Grey-Token: YOUR_LOCAL_TOKEN' http://127.0.0.1:8765/health
```

## Important limits / current status

- This is a prototype, not yet verified on the user's phone. Terhux must not claim CapCut control until the APK is built, installed, accessibility is manually enabled, and a real test succeeds.
- This controls visible UI only. It is not a CapCut API, and it cannot guarantee stable editing because UI layouts can change.
- No cookie, password, OTP, browser profile, localStorage, or auth-token extraction is implemented.
- Do not use it to auto-submit forms, make purchases, accept terms, bypass CAPTCHAs, or perform other consequential actions without the user's direct control.
- The app does not start the accessibility service or grant itself accessibility permission. The user must explicitly enable it in Android Settings.
- The local token is shown in the companion UI and stored in private app preferences. The prototype does not log it.
- This bridge currently offers low-level controls; a separate Terhux integration still needs to be wired to send approved commands after the user supplies the token securely.
