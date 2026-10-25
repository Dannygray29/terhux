# GREY Chrome Bridge — Android proof of concept

## Scope and limitations
Termux alone cannot inspect or control the existing Chrome tab DOM through Android's normal app sandbox. termux-open-url only launches a URL and is not session automation. The intended supported route is a user-installed Android AccessibilityService companion that the user explicitly enables in Android Settings. This prototype must not access Chrome cookies, passwords, OTPs, or browser profile files.

## Phase 1
- Keep any HTTP control endpoint bound to 127.0.0.1 only.
- Require a high-entropy local token for commands; never print the token.
- Support read-only status/navigation first.
- Return active browser package and accessibility window metadata, and extract visible text from the accessibility tree only after the user enables the companion service.
- Do not submit forms, send messages, purchase items, or accept terms automatically.
- The user handles passwords, OTPs, and CAPTCHAs.
- Do not claim Chrome control works until installed companion, explicit accessibility enablement, and a real Chrome page test all pass.

## Current device evidence
The phone is Android 15 / API 35 and package com.android.chrome exists. adb devices returned no attached debugging device, and enabled_accessibility_services was empty at the time of inspection. Therefore a working same-session bridge is not currently verified.

## Required next steps
Create an Android companion project only if the available Android build toolchain supports it. Otherwise provide complete source and precise build/install/enable steps. Never install or enable accessibility silently.
