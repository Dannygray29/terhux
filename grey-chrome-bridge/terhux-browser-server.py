#!/usr/bin/env python3
"""Local-only, allowlisted GREY Browser command queue for Terhux."""
import json, os, secrets, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

HOST, PORT = "127.0.0.1", 8789
STATE = Path.home() / ".local/state/terhux"
TOKEN_FILE = STATE / "grey-browser-token"
QUEUE_FILE = STATE / "grey-browser-commands.json"
RESULTS_FILE = STATE / "grey-browser-results.jsonl"
LOCK = threading.RLock()
ALLOWED = {"navigate", "back", "forward", "reload", "status", "visible-text"}

def read_queue():
    try:
        data = json.loads(QUEUE_FILE.read_text())
        return data if isinstance(data, list) else []
    except (OSError, ValueError):
        return []

def write_queue(items):
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = QUEUE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(items))
    os.replace(tmp, QUEUE_FILE)

def current_token():
    try:
        return TOKEN_FILE.read_text().strip()
    except OSError:
        return ""

def reply(handler, code, payload):
    raw = json.dumps(payload).encode()
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(raw)))
    handler.end_headers()
    handler.wfile.write(raw)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass
    def read_body(self):
        try:
            n = min(int(self.headers.get("Content-Length", "0")), 65536)
            return json.loads(self.rfile.read(n) or b"{}")
        except (ValueError, OSError):
            return {}
    def authorized(self):
        token = current_token()
        return bool(token) and secrets.compare_digest(
            self.headers.get("Authorization", ""), "Bearer " + token)
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/v1/browser/health":
            reply(self, 200, {"ok": True, "paired": bool(current_token()), "host": HOST, "port": PORT})
            return
        if path == "/v1/browser/next":
            if not self.authorized():
                reply(self, 401, {"error": "unauthorized"}); return
            with LOCK:
                q = read_queue()
                item = q.pop(0) if q else None
                if item is not None: write_queue(q)
            reply(self, 200, {"command": item})
            return
        reply(self, 404, {"error": "not found"})
    def do_POST(self):
        path = urlparse(self.path).path
        data = self.read_body()
        if path == "/v1/browser/pair":
            token = data.get("token", "")
            if not isinstance(token, str) or len(token) < 32:
                reply(self, 400, {"error": "invalid pairing token"}); return
            STATE.mkdir(parents=True, exist_ok=True)
            with LOCK:
                existing = current_token()
                if existing and not secrets.compare_digest(existing, token):
                    reply(self, 409, {"error": "already paired; reset pairing from Termux to replace it"}); return
                if not existing:
                    tmp = TOKEN_FILE.with_suffix(".tmp")
                    tmp.write_text(token)
                    try: tmp.chmod(0o600)
                    except OSError: pass
                    os.replace(tmp, TOKEN_FILE)
            reply(self, 200, {"ok": True, "paired": True}); return
        if path == "/v1/browser/result":
            if not self.authorized():
                reply(self, 401, {"error": "unauthorized"}); return
            if not isinstance(data, dict) or not data.get("id"):
                reply(self, 400, {"error": "result id required"}); return
            STATE.mkdir(parents=True, exist_ok=True)
            data["received_at"] = int(time.time())
            with LOCK:
                with RESULTS_FILE.open("a") as f: f.write(json.dumps(data) + "\n")
            reply(self, 200, {"ok": True}); return
        reply(self, 404, {"error": "not found"})

def main():
    STATE.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"GREY Browser local bridge listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()

if __name__ == "__main__":
    main()
