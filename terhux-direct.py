#!/usr/bin/env python3
"""Terhux direct agent bridge: AI agent <-> HTTP <-> Termux."""
from __future__ import annotations
import json, os, secrets, subprocess, threading, time, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = os.environ.get("TERHUX_DIRECT_HOST", "127.0.0.1")
PORT = int(os.environ.get("TERHUX_DIRECT_PORT", "8787"))
TOKEN_FILE = Path(os.environ.get("TERHUX_DIRECT_TOKEN_FILE", str(Path.home() / ".terhux-direct-token")))
WORKDIR = Path(os.environ.get("TERHUX_DIRECT_WORKDIR", str(Path.home()))).resolve()
TIMEOUT = int(os.environ.get("TERHUX_DIRECT_TIMEOUT", "120"))
MAX_OUTPUT = 100_000
JOBS: dict[str, dict] = {}
LOCK = threading.Lock()

def token() -> str:
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text(encoding="utf-8").strip()
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    value = secrets.token_urlsafe(32)
    TOKEN_FILE.write_text(value, encoding="utf-8")
    os.chmod(TOKEN_FILE, 0o600)
    return value

AUTH_TOKEN = token()

def reply(handler, code, payload):
    raw = json.dumps(payload, ensure_ascii=False).encode()
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(raw)))
    handler.end_headers()
    handler.wfile.write(raw)

class Handler(BaseHTTPRequestHandler):
    server_version = "TerhuxDirect/1.0"

    def log_message(self, fmt, *args):
        return

    def authorized(self):
        return secrets.compare_digest(self.headers.get("Authorization", ""), "Bearer " + AUTH_TOKEN)

    def do_GET(self):
        if self.path == "/health":
            return reply(self, 200, {"ok": True, "service": "terhux-direct", "version": "1.0"})
        if not self.authorized():
            return reply(self, 401, {"ok": False, "error": "unauthorized"})
        if self.path.startswith("/v1/jobs/"):
            job_id = self.path.rsplit("/", 1)[-1]
            with LOCK:
                job = JOBS.get(job_id)
            if not job:
                return reply(self, 404, {"ok": False, "error": "job_not_found"})
            return reply(self, 200, job)
        return reply(self, 404, {"ok": False, "error": "not_found"})

    def do_POST(self):
        if not self.authorized():
            return reply(self, 401, {"ok": False, "error": "unauthorized"})
        if self.path != "/v1/execute":
            return reply(self, 404, {"ok": False, "error": "not_found"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 32_000:
                return reply(self, 413, {"ok": False, "error": "request_too_large"})
            data = json.loads(self.rfile.read(length) or b"{}")
            command = data.get("command")
            cwd = Path(data.get("cwd") or WORKDIR).expanduser().resolve()
            timeout = min(int(data.get("timeout", TIMEOUT)), TIMEOUT)
            if not isinstance(command, str) or not command.strip():
                return reply(self, 400, {"ok": False, "error": "command_required"})
            if not cwd.is_relative_to(WORKDIR):
                return reply(self, 403, {"ok": False, "error": "cwd_outside_workdir"})
        except Exception as exc:
            return reply(self, 400, {"ok": False, "error": str(exc)})

        job_id = "job-" + uuid.uuid4().hex
        with LOCK:
            JOBS[job_id] = {"id": job_id, "status": "running", "started_at": time.time()}

        def run():
            try:
                p = subprocess.run(["bash", "-lc", command], cwd=cwd, capture_output=True, text=True, timeout=timeout)
                result = {
                    "id": job_id, "status": "success" if p.returncode == 0 else "error",
                    "exit_code": p.returncode, "stdout": p.stdout[-MAX_OUTPUT:], "stderr": p.stderr[-MAX_OUTPUT:],
                    "finished_at": time.time(),
                }
            except subprocess.TimeoutExpired as exc:
                result = {"id": job_id, "status": "timeout", "exit_code": None,
                          "stdout": (exc.stdout or "")[-MAX_OUTPUT:], "stderr": (exc.stderr or "")[-MAX_OUTPUT:],
                          "finished_at": time.time()}
            except Exception as exc:
                result = {"id": job_id, "status": "error", "error": str(exc), "finished_at": time.time()}
            with LOCK:
                JOBS[job_id] = result

        threading.Thread(target=run, daemon=True).start()
        return reply(self, 202, {"ok": True, "id": job_id, "status": "running",
                                 "result_url": "/v1/jobs/" + job_id})

if __name__ == "__main__":
    print("TERHUX_DIRECT_READY")
    print(f"LISTEN={HOST}:{PORT}")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
