#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.request

BASE = os.environ["TERHUX_RELAY_URL"].rstrip("/")
TOKEN = os.environ["TERHUX_RELAY_TOKEN"]
AGENT_ID = os.environ.get("TERHUX_AGENT_ID", "termux-phone")
POLL = max(1, int(os.environ.get("TERHUX_AGENT_POLL_SECONDS", "1")))
WAIT = max(1, int(os.environ.get("TERHUX_AGENT_WAIT_SECONDS", "120")))

def request(path, method="GET", payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        BASE + path,
        data=data,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Content-Type": "application/json",
        },
        method=method,
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode() or "{}")

if len(sys.argv) < 2:
    print("usage: terhux-agent.py '<command>'")
    raise SystemExit(2)

job = request(
    "/v1/jobs",
    "POST",
    {"agent_id": AGENT_ID, "command": " ".join(sys.argv[1:])},
)

job_id = job["id"]
deadline = time.time() + WAIT

while time.time() < deadline:
    result = request("/v1/jobs/" + job_id)
    if result.get("status") not in ("queued", "claimed", "running"):
        print(json.dumps(result, indent=2))
        raise SystemExit(0 if result.get("status") == "success" else 1)
    time.sleep(POLL)

print(json.dumps({
    "id": job_id,
    "status": "timeout",
    "error": "agent_wait_timeout",
}))
raise SystemExit(1)
