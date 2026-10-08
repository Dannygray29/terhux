from __future__ import annotations

import json
import os
import time
import uuid
from http.server import BaseHTTPRequestHandler

TOKEN = os.environ.get("TERHUX_RELAY_TOKEN", "")
JOBS: dict[str, dict] = {}
TTL = 3600
ALLOWED_AGENTS = {"termux-phone"}


def auth(handler: BaseHTTPRequestHandler) -> bool:
    value = handler.headers.get("Authorization", "")
    return bool(TOKEN) and value == "Bearer " + TOKEN


def clean() -> None:
    cutoff = time.time() - TTL
    for job_id, job in list(JOBS.items()):
        if job.get("created_at", 0) < cutoff:
            JOBS.pop(job_id, None)


class handler(BaseHTTPRequestHandler):
    def send_json(self, status: int, payload: dict) -> None:
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:
        clean()
        if self.path == "/health":
            self.send_json(200, {"ok": True, "service": "terhux-relay"})
            return
        if not auth(self):
            self.send_json(401, {"ok": False, "error": "unauthorized"})
            return

        parts = self.path.strip("/").split("/")
        if len(parts) == 4 and parts[:2] == ["v1", "agents"] and parts[3] == "next":
            agent_id = parts[2]
            for job in JOBS.values():
                if job["agent_id"] == agent_id and job["status"] == "queued":
                    job["status"] = "claimed"
                    self.send_json(200, {"job": job})
                    return
            self.send_json(200, {"job": None})
            return

        if len(parts) == 3 and parts[:2] == ["v1", "jobs"]:
            job = JOBS.get(parts[2])
            self.send_json(200 if job else 404, job or {"error": "not_found"})
            return

        self.send_json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:
        if not auth(self):
            self.send_json(401, {"ok": False, "error": "unauthorized"})
            return

        clean()
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json(400, {"ok": False, "error": "invalid_content_length"})
            return

        if length > 32768:
            self.send_json(413, {"ok": False, "error": "payload_too_large"})
            return

        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            self.send_json(400, {"ok": False, "error": "invalid_json"})
            return

        parts = self.path.strip("/").split("/")
        if self.path == "/v1/jobs":
            agent_id = payload.get("agent_id")
            command = payload.get("command")
            project = payload.get("project")
            if not isinstance(agent_id, str) or not agent_id.strip():
                self.send_json(400, {"ok": False, "error": "agent_id_required"})
                return
            if agent_id not in ALLOWED_AGENTS:
                self.send_json(403, {"ok": False, "error": "agent_not_allowed"})
                return
            if not isinstance(command, str) or not command.strip():
                self.send_json(400, {"ok": False, "error": "command_required"})
                return
            if project is not None and (
                not isinstance(project, str) or len(project) > 128
            ):
                self.send_json(400, {"ok": False, "error": "invalid_project"})
                return

            job_id = uuid.uuid4().hex
            job = {
                "id": job_id,
                "agent_id": agent_id,
                "project": project,
                "command": command,
                "cwd": payload.get("cwd"),
                "timeout": payload.get("timeout"),
                "status": "queued",
                "created_at": time.time(),
            }
            JOBS[job_id] = job
            self.send_json(202, {"ok": True, "id": job_id, "status": "queued"})
            return

        if len(parts) == 4 and parts[:2] == ["v1", "jobs"] and parts[3] == "result":
            job = JOBS.get(parts[2])
            if not job:
                self.send_json(404, {"ok": False, "error": "not_found"})
                return
            job["result"] = payload
            job["status"] = payload.get("status", "completed")
            job["completed_at"] = time.time()
            self.send_json(200, {"ok": True, "id": job["id"], "status": job["status"]})
            return

        self.send_json(404, {"ok": False, "error": "not_found"})
