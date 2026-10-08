#!/usr/bin/env python3
"""Terhux outbound relay client.

Phone-side transport for:
AI agent -> relay -> Termux -> relay -> AI agent.

The phone makes only outbound HTTP requests. Remote commands are never
accepted directly by the Termux listener.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

RELAY_URL = os.environ.get("TERHUX_RELAY_URL", "").rstrip("/")
RELAY_TOKEN = os.environ.get("TERHUX_RELAY_TOKEN", "")
AGENT_ID = os.environ.get("TERHUX_AGENT_ID", "termux-phone")
POLL_SECONDS = max(2, int(os.environ.get("TERHUX_RELAY_POLL_SECONDS", "5")))
DIRECT_URL = os.environ.get("TERHUX_DIRECT_URL", "http://127.0.0.1:8787")
DIRECT_TOKEN_FILE = os.environ.get(
    "TERHUX_DIRECT_TOKEN_FILE",
    os.path.expanduser("~/.terhux-direct-token"),
)

def headers(token: str) -> dict[str, str]:
    return {"Authorization": "Bearer " + token, "Content-Type": "application/json"}

def request_json(url: str, token: str, method: str = "GET", payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, headers=headers(token), method=method)
    with urllib.request.urlopen(req, timeout=30) as response:
        raw = response.read()
        return json.loads(raw or b"{}")

def direct_token() -> str:
    with open(DIRECT_TOKEN_FILE, encoding="utf-8") as fh:
        return fh.read().strip()

def execute_local(command: str, cwd=None, timeout=None):
    payload = {"command": command}
    if cwd:
        payload["cwd"] = cwd
    if timeout is not None:
        payload["timeout"] = timeout
    return request_json(
        DIRECT_URL + "/v1/execute",
        direct_token(),
        method="POST",
        payload=payload,
    )

def get_result(job_url: str):
    return request_json(DIRECT_URL + job_url, direct_token())

def main():
    if not RELAY_URL or not RELAY_TOKEN:
        print("TERHUX_RELAY_DISABLED", flush=True)
        return 0

    print("TERHUX_RELAY_STARTING", AGENT_ID, flush=True)
    while True:
        try:
            request_json(
                RELAY_URL + "/health",
                RELAY_TOKEN,
                method="GET",
            )
            job = request_json(
                RELAY_URL + "/v1/agents/" + AGENT_ID + "/next",
                RELAY_TOKEN,
                method="GET",
            )
            if job.get("job"):
                item = job["job"]
                command = item.get("command")
                if not isinstance(command, str) or not command.strip():
                    result = {"status": "error", "error": "invalid_command"}
                else:
                    try:
                        started = execute_local(
                            command,
                            cwd=item.get("cwd"),
                            timeout=item.get("timeout"),
                        )
                        result = started
                        if started.get("status") == "running":
                            while True:
                                result = get_result(started["result_url"])
                                if result.get("status") != "running":
                                    break
                                time.sleep(1)
                    except Exception as exc:
                        result = {"status": "error", "error": str(exc)}
                request_json(
                    RELAY_URL + "/v1/jobs/" + str(item["id"]) + "/result",
                    RELAY_TOKEN,
                    method="POST",
                    payload=result,
                )
                print("TERHUX_RELAY_JOB", item["id"], result.get("status"), flush=True)
            else:
                time.sleep(POLL_SECONDS)
        except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
            print("TERHUX_RELAY_WAIT", type(exc).__name__, flush=True)
            time.sleep(POLL_SECONDS)
        except Exception as exc:
            print("TERHUX_RELAY_ERROR", type(exc).__name__, flush=True)
            time.sleep(POLL_SECONDS)

if __name__ == "__main__":
    raise SystemExit(main())
