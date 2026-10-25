#!/usr/bin/env python3
"""Queue safe GREY Browser actions for the foreground GREY Browser app."""
import argparse, json, os, sys, time, uuid
from pathlib import Path
from urllib.parse import urlparse

STATE = Path.home() / ".local/state/terhux"
QUEUE = STATE / "grey-browser-commands.json"
RESULTS = STATE / "grey-browser-results.jsonl"
ALLOWED = {"navigate", "back", "forward", "reload", "status", "visible-text"}

def load_queue():
    try:
        v = json.loads(QUEUE.read_text())
        return v if isinstance(v, list) else []
    except (OSError, ValueError):
        return []

def enqueue(action, url=None):
    if action not in ALLOWED:
        raise SystemExit("Unsupported action.")
    if action == "navigate":
        u = urlparse(url or "")
        if u.scheme not in ("http", "https") or not u.netloc:
            raise SystemExit("navigate requires a valid http:// or https:// URL.")
    elif url:
        raise SystemExit("URL is only valid for navigate.")
    STATE.mkdir(parents=True, exist_ok=True)
    ident = uuid.uuid4().hex
    item = {"id": ident, "action": action}
    if url: item["url"] = url
    QUEUE.write_text(json.dumps(load_queue() + [item]))
    print("QUEUED_ID=" + ident)
    print("ACTION=" + action)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("enqueue")
    e.add_argument("action", choices=sorted(ALLOWED))
    e.add_argument("url", nargs="?")
    sub.add_parser("status")
    r = sub.add_parser("results")
    r.add_argument("--tail", type=int, default=10)
    sub.add_parser("reset-pairing")
    a = p.parse_args()
    if a.cmd == "enqueue": enqueue(a.action, getattr(a, "url", None))
    elif a.cmd == "status":
        import urllib.request
        try:
            with urllib.request.urlopen("http://127.0.0.1:8789/v1/browser/health", timeout=2) as response:
                health = json.load(response)
            print("SERVER_PROCESS=running")
            print("HEALTH_CHECK=PASS")
            print("SERVER_PAIRED=" + str(health.get("paired", False)))
        except Exception:
            print("SERVER_PROCESS=not-detected")
            print("HEALTH_CHECK=FAIL")
        print("QUEUED_COMMANDS=" + str(len(load_queue())))
        print("PAIRING=" + ("configured" if (STATE / "grey-browser-token").exists() else "not-paired"))
    elif a.cmd == "results":
        try: lines = RESULTS.read_text().splitlines()
        except OSError: lines = []
        for line in lines[-max(1, a.tail):]:
            try:
                v = json.loads(line)
                print(json.dumps(v, ensure_ascii=False))
            except ValueError: pass
    elif a.cmd == "reset-pairing":
        token = STATE / "grey-browser-token"
        try: token.unlink(); print("PAIRING_RESET")
        except FileNotFoundError: print("PAIRING_ALREADY_RESET")
if __name__ == "__main__": main()
