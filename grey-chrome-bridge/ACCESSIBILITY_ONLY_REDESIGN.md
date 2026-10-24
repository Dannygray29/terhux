# GREY Chrome Bridge — Accessibility-only redesign

## Product scope

GREY Chrome Bridge is a general Android Chrome UI bridge for Terhux, not a CapCut-only integration. It should operate on the currently visible Chrome UI across ordinary websites: inspect visible accessibility labels, tap, scroll, and enter ordinary text where Android Accessibility permits it. It must not extract cookies, browser databases, passwords, OTPs, session tokens, or hidden page storage.

## Hard requirements

- The only additional Android permission the user should need to grant is enabling GREY Chrome Bridge in Accessibility Settings.
- No Termux "allow external apps to run commands" setting.
- No manual token copying.
- Preserve existing Chrome sign-in sessions by operating the visible UI.
- Keep a secure command boundary; do not ship an unauthenticated localhost control API.
- Never claim the live phone works until the APK is built, installed, and tested on-device.

## Architecture blocker and decision

Android application sandboxing prevents a companion app from directly writing to Termux's private files or launching Termux commands unless an explicit IPC/command permission is granted. Therefore the current prototype's token transfer through Termux RUN_COMMAND cannot satisfy the permission requirement.

A replacement must use a mutually authenticated relay or a user-approved local pairing protocol. A relay design requires both the Termux worker and the Android accessibility companion to make outbound connections, plus secure pairing, expiring credentials, and authorization checks. A local design can bind only to loopback, but must not treat loopback alone as authentication; the app must explicitly approve pairing/commands or use a credential exchange that does not require secret copying. Do not weaken the bridge by removing authentication or exposing the control listener to the LAN.

## Required user experience

1. User installs GREY Chrome Bridge and explicitly enables its Accessibility Service once in Android Settings.
2. User taps Connect in the companion app.
3. Terhux discovers/pairs without a token being displayed, copied, pasted, or written via Termux RUN_COMMAND.
4. User can direct Terhux to control the visible Chrome interface on any site, with confirmation before consequential actions such as submitting forms, purchases, account/security changes, or accepting terms.
5. The bridge reports connection state and last successful command; errors must be visible and truthful.

## General Chrome interaction contract

Expose stable operations such as health/status, foreground-app check, visible accessibility tree/labels, tap by coordinates or accessible node, scroll, back, and text entry into ordinary non-sensitive fields. Keep Chrome as the foreground app for browser actions. Accessibility APIs may not expose all page content or reliably distinguish every control; return explicit limitations instead of guessing.

## Verification checklist

- [ ] Debug APK builds in CI.
- [ ] Manifest declares only the permissions needed for the Accessibility Service (no broad storage, overlay, VPN, or external-command permissions).
- [ ] No Termux RUN_COMMAND invocation remains in the connection path.
- [ ] Pairing is authenticated and cannot be triggered by arbitrary local apps without user approval.
- [ ] Terhux can connect without copying/pasting credentials.
- [ ] Real Android test: open a normal website in Chrome, read visible labels, tap a harmless link, scroll, and verify status.
- [ ] Real Android test: open CapCut in the existing Chrome session without logging in again.
- [ ] Test disconnection, app restart, expired pairing, and denied actions.
- [ ] No success claim until on-device checks above are completed.

## Current status

This document records the acceptance criteria and architecture constraint. It does not mean the replacement implementation or live-device test is complete.
