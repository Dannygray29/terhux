#!/usr/bin/env python3
"""Minimal authenticated Terhux relay protocol.

Environment:
  TERHUX_RELAY_TOKEN  shared secret
  TERHUX_RELAY_HOST   default 127.0.0.1
  TERHUX_RELAY_PORT   default 8790

This is intentionally a protocol server only. It does not expose Termux
commands until the phone-side relay client is wired to consume authenticated
jobs.
"""
import json
import os
import secrets
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ.get("TERHUX_RELAY_TOKEN", "")
HOST = os.environ.get("TERHUX_RELAY_HOST", "127.0.0.1")
PORT = int(os.environ.get("TERHUX_RELAY_PORT", "8790"))

class Handler(BaseHTTPRequestHandler):
    server_version = "TerhuxRelay/1.0"

    def _send(self, code, payload):
        raw = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _auth(self):
        if not TOKEN:
            return False
        return secrets.compare_digest(
            self.headers.get("Authorization", ""),
            "Bearer " + TOKEN,
        )

    def do_GET(self):
        if self.path == "/health":
            return self._send(200, {"ok": True, "service": "terhux-relay", "version": "1.0"})
        if not self._auth():
            return self._send(401, {"ok": False, "error": "unauthorized"})
        if self.path == "/v1/poll":
            return self._send(200, {"ok": True, "jobs": []})
        return self._send(404, {"ok": False, "error": "not_found"})

    def do_POST(self):
        if not self._auth():
            return self._send(401, {"ok": False, "error": "unauthorized"})
        if self.path == "/v1/result":
            return self._send(202, {"ok": True, "accepted": True})
        return self._send(404, {"ok": False, "error": "not_found"})

    def log_message(self, *_):
        pass

if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
