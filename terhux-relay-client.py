#!/usr/bin/env python3
"""Terhux outbound relay client scaffold.

The client intentionally does not expose a listening socket. It will maintain
an authenticated outbound connection to a relay configured by environment.
"""

import os
import time
import urllib.request

RELAY_URL = os.environ.get("TERHUX_RELAY_URL", "").rstrip("/")
RELAY_TOKEN_FILE = os.environ.get(
    "TERHUX_RELAY_TOKEN_FILE",
    os.path.expanduser("~/.terhux-relay-token"),
)

def load_token():
    try:
        with open(RELAY_TOKEN_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""

def health_check():
    if not RELAY_URL:
        return False
    token = load_token()
    if not token:
        return False
    req = urllib.request.Request(
        RELAY_URL + "/v1/health",
        headers={"Authorization": "Bearer " + token},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.status == 200
    except Exception:
        return False

if __name__ == "__main__":
    print("TERHUX_RELAY_CLIENT_READY")
    if not RELAY_URL:
        print("RELAY=unconfigured")
    else:
        print("RELAY=" + RELAY_URL)
        print("HEALTH=" + ("ok" if health_check() else "unreachable"))
