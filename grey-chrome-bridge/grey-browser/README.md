# GREY Browser — local-first prototype

GREY Browser is a standalone Android companion module under the existing GREY Chrome Bridge project. It is intentionally isolated from Terhux core: no Terhux scripts, boot files, ports, configuration, or credentials are changed.

## Engine choice

This first prototype uses Android System WebView, which is Chromium-based and maintained through the Android system/WebView provider. It is **not** a separately bundled full Chromium distribution. This is the lowest-risk way to validate a local browser UI on Android before considering a full Chromium package, which would be much larger and more difficult to maintain.

## Current scope

- Local browser UI: address/search bar, back, forward, reload and loading indicator.
- HTTP/HTTPS navigation only; other schemes are rejected.
- JavaScript and DOM storage enabled for modern sites.
- File/content access from web pages disabled; mixed content blocked.
- No JavaScript interface exposed to arbitrary websites.
- Browser profile remains in this app's private storage.
- No cloud browser, paid API, or additional backend.
- Independent APK build workflow.

## Not yet implemented

- Terhux local command link: use More options → Connect Terhux while Termux's localhost bridge is running.
- Allowlisted navigation, back, forward, reload and current-URL status commands.
- Download manager and download destination controls.
- Persistent cross-device profile sync.
- Verified compatibility with CapCut or any specific site.
- A full separately bundled Chromium runtime.

These are deliberate omissions, not completed features. The module must not be described as fully automated until the integration and device tests pass.

## Build

GitHub Actions workflow: **Build GREY Browser APK**. Run it manually or push changes under `grey-chrome-bridge/grey-browser/**`. The workflow uploads a debug APK artifact; it does not modify or replace Terhux or the existing Chrome Bridge APK.

## Security notes

Do not add `addJavascriptInterface` for arbitrary page content. A future Terhux controller should use a narrow, authenticated, app-owned command boundary and must never allow page content to execute shell commands. Cookies, passwords, and browser profile data must not be copied into GitHub.

## Terhux local link
The app polls 127.0.0.1:8789 while open. Pairing begins only after the user taps Connect Terhux. Commands are allowlisted and never execute shell commands; no cookies, passwords, OTPs, form submissions, messages or purchases are exposed.

## Installation note
This Terhux-enabled build uses a separate Android package ID and displays as GREY Browser Link, so it can be installed alongside an existing GREY Browser without uninstalling it or deleting its private browser data.
