#!/usr/bin/env python3
"""Terhux outbound relay client.

Keeps the phone-side component outbound-only. The relay URL is supplied by
TERHUX_RELAY_URL and the bearer token by TERHUX_RELAY_TOKEN. This scaffold
does not execute remote commands until a relay endpoint is configured.
"""
import os
import time
import urllib.request

RELAY_URL = os.environ.get("TERHUX_RELAY_URL", "").rstrip("/")
TOKEN = os.environ.get("TERHUX_RELAY_TOKEN", "")

def main():
    if not RELAY_URL or not TOKEN:
        print("TERHUX_RELAY_DISABLED")
        return 0
    health = RELAY_URL + "/health"
    req = urllib.request.Request(
        health,
        headers={"Authorization": "Bearer " + TOKEN},
        method="GET",
    )
    while True:
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                print("TERHUX_RELAY_CONNECTED", response.status, flush=True)
        except Exception as exc:
            print("TERHUX_RELAY_WAIT", type(exc).__name__, flush=True)
        time.sleep(30)

if __name__ == "__main__":
    raise SystemExit(main())
