#!/usr/bin/env python3
"""Consume authenticated GitHub Issues for the phone-hosted Terhux bridge."""
from __future__ import annotations

import base64
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

REPO_DIR = Path(os.environ.get("TERHUX_REPO_DIR", str(Path.home() / "terhux/repo"))).resolve()
REPO_SLUG = os.environ.get("TERHUX_GITHUB_REPO", "Dannygray29/terhux")
LABEL = os.environ.get("TERHUX_REQUEST_LABEL", "terhux-request")
CONFIG_DIR = Path.home() / ".config/terhux"
PRIVATE_KEY = Path(os.environ.get("TERHUX_PRIVATE_KEY_FILE", str(CONFIG_DIR / "access-private.pem")))
PIN_HASH = Path(os.environ.get("TERHUX_PIN_HASH_FILE", str(CONFIG_DIR / "pin-hash.json")))
PUBLIC_CERT = REPO_DIR / "terhux-access-cert.pem"
RATE_FILE = CONFIG_DIR / "auth-failures.json"
ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,80}$")
FIELD_RE = re.compile(r"^[A-Z_]+$")
ALLOWED_FIELDS = {
    "ID", "ACTION", "PROJECT", "PATH", "CONTENT_B64", "FROM_B64",
    "TO_B64", "PACKAGE", "NEW_NAME", "APPROVED",
}
WINDOW_SECONDS = 24 * 60 * 60
PER_USER_LIMIT = 5
GLOBAL_LIMIT = 20


def log(message: str) -> None:
    log_dir = REPO_DIR / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    with (log_dir / "bridge.log").open("a", encoding="utf-8") as stream:
        stream.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")


def gh(args: list[str], *, timeout: int = 30) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["gh", *args, "--repo", REPO_SLUG],
        cwd=REPO_DIR,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
        env={**os.environ, "GH_PROMPT_DISABLED": "1"},
    )


def issue_comment(number: int, body: str) -> bool:
    result = gh(["issue", "comment", str(number), "--body", body])
    if result.returncode:
        log(f"could not comment on issue #{number}: gh exit {result.returncode}")
        return False
    return True


def remove_request_label(number: int) -> bool:
    result = gh(["issue", "edit", str(number), "--remove-label", LABEL])
    if result.returncode:
        log(f"could not remove request label from issue #{number}: gh exit {result.returncode}")
        return False
    return True


def close_issue(number: int) -> bool:
    result = gh(["issue", "close", str(number), "--reason", "completed"])
    if result.returncode:
        log(f"could not close issue #{number}: gh exit {result.returncode}")
        return False
    return True


def has_marker(number: int, marker: str) -> bool:
    result = gh(["issue", "view", str(number), "--json", "comments", "--jq", ".comments[].body"])
    return result.returncode == 0 and marker.encode() in result.stdout


def respond_once(number: int, marker: str, body: str) -> bool:
    if not has_marker(number, marker):
        if not issue_comment(number, body):
            return False
    return True


def read_rate_state() -> dict:
    try:
        state = json.loads(RATE_FILE.read_text(encoding="utf-8"))
        if not isinstance(state, dict):
            raise ValueError
        return state
    except (OSError, ValueError, json.JSONDecodeError):
        return {"global": [], "users": {}}


def prune_times(values: list, now: int) -> list[int]:
    return [int(t) for t in values if isinstance(t, (int, float)) and now - int(t) < WINDOW_SECONDS]


def rate_state(author: str) -> tuple[dict, bool]:
    now = int(time.time())
    state = read_rate_state()
    state["global"] = prune_times(state.get("global", []), now)
    users = state.setdefault("users", {})
    user_times = prune_times(users.get(author, []), now)
    users[author] = user_times
    blocked = len(user_times) >= PER_USER_LIMIT or len(state["global"]) >= GLOBAL_LIMIT
    return state, blocked


def write_rate_state(state: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = RATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, separators=(",", ":")), encoding="utf-8")
    os.chmod(temporary, 0o600)
    temporary.replace(RATE_FILE)
    os.chmod(RATE_FILE, 0o600)


def add_auth_failure(state: dict, author: str) -> None:
    now = int(time.time())
    state["global"] = prune_times(state.get("global", []), now)
    state["global"].append(now)
    users = state.setdefault("users", {})
    users[author] = prune_times(users.get(author, []), now) + [now]
    write_rate_state(state)


def clear_user_failures(author: str) -> None:
    state = read_rate_state()
    state["users"] = state.get("users", {})
    state["users"].pop(author, None)
    write_rate_state(state)


def auth_response(number: int, code: str, message: str) -> None:
    marker = f"TERHUX_AUTH:{number}:{code}"
    body = f"{marker}\n{message}"
    if respond_once(number, marker, body):
        remove_request_label(number)


def parse_envelope(body: str) -> bytes:
    lines = body.splitlines()
    if len(lines) != 2 or lines[0].strip() != "TERHUX_CMS_V1" or not lines[1].startswith("PAYLOAD_B64="):
        raise ValueError("invalid envelope format")
    payload = base64.b64decode(lines[1].split("=", 1)[1], validate=True)
    if not payload or len(payload) > 48_000:
        raise ValueError("envelope size is invalid")
    return payload


def decrypt_payload(envelope: bytes) -> dict:
    if not PRIVATE_KEY.is_file() or not PUBLIC_CERT.is_file() or not PIN_HASH.is_file():
        raise FileNotFoundError("local authentication is not initialized")
    result = subprocess.run(
        ["openssl", "cms", "-decrypt", "-binary", "-inform", "DER",
         "-in", "-", "-out", "-", "-recip", str(PUBLIC_CERT), "-inkey", str(PRIVATE_KEY)],
        input=envelope,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=20,
        check=False,
    )
    if result.returncode:
        raise ValueError("envelope decryption failed")
    if len(result.stdout) > 32_000:
        raise ValueError("decrypted request is too large")
    payload = json.loads(result.stdout.decode("utf-8"))
    if not isinstance(payload, dict) or payload.get("protocol") != "TERHUX_ISSUE_V1":
        raise ValueError("invalid decrypted request")
    if not isinstance(payload.get("pin"), str) or not isinstance(payload.get("fields"), dict):
        raise ValueError("invalid decrypted request fields")
    return payload


def verify_pin(pin: str) -> bool:
    result = subprocess.run(
        [sys.executable, str(REPO_DIR / "terhux-auth.py"), "verify-pin", str(PIN_HASH)],
        input=pin.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        timeout=30,
        check=False,
    )
    return result.returncode == 0


def validate_fields(fields: dict) -> tuple[str, str]:
    if not fields or any(not isinstance(k, str) or not FIELD_RE.fullmatch(k) for k in fields):
        raise ValueError("field names are invalid")
    if set(fields) - ALLOWED_FIELDS:
        raise ValueError("request contains unsupported fields")
    if any(not isinstance(v, str) or "\n" in v or "\r" in v or "\x00" in v for v in fields.values()):
        raise ValueError("field values must be single-line strings")
    request_id = fields.get("ID", "")
    if not ID_RE.fullmatch(request_id):
        raise ValueError("ID must use 1-80 letters, digits, dots, underscores, or hyphens")
    if not fields.get("ACTION"):
        raise ValueError("ACTION is required")
    if fields.get("APPROVED") != "true":
        raise ValueError("APPROVED=true is required")
    return request_id, "\n".join(f"{key}={fields[key]}" for key in sorted(fields)) + "\n"


def runner_result(request_id: str, command_text: str) -> Path:
    result_file = REPO_DIR / "results" / f"{request_id}.result"
    if result_file.exists():
        return result_file
    incoming = REPO_DIR / "commands" / ".incoming"
    incoming.mkdir(parents=True, exist_ok=True, mode=0o700)
    command_file = incoming / f"{request_id}.cmd"
    command_file.write_text(command_text, encoding="utf-8")
    os.chmod(command_file, 0o600)

    process = subprocess.Popen(
        ["bash", str(REPO_DIR / "terhux-runner.sh"), str(command_file)],
        cwd=REPO_DIR,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env=os.environ.copy(),
    )
    try:
        process.wait(timeout=1900)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    return result_file


def summarize_result(request_id: str, result_file: Path) -> tuple[str, str]:
    status, exit_code = "ERROR", "1"
    try:
        for line in result_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("STATUS="):
                status = line.split("=", 1)[1]
            elif line.startswith("EXIT_CODE="):
                exit_code = line.split("=", 1)[1]
    except OSError:
        pass
    url = f"https://github.com/{REPO_SLUG}/blob/main/results/{request_id}.result"
    return status, f"TERHUX_RESULT:{request_id}\nRequest `{request_id}` finished with status **{status}** (exit `{exit_code}`).\nResult: {url}"


def process_issue(issue: dict) -> None:
    number = int(issue["number"])
    author_obj = issue.get("author") or {}
    author = str(author_obj.get("login", "unknown"))
    body = str(issue.get("body") or "")

    if not PRIVATE_KEY.is_file() or not PUBLIC_CERT.is_file() or not PIN_HASH.is_file():
        auth_response(number, "SETUP", "Phone-side password setup is not complete. Ask the repository owner to run `terhux-auth-init.sh` in Termux, then submit a new encrypted request. No request was executed.")
        return

    state, blocked = rate_state(author)
    if blocked:
        auth_response(number, "LOCKED", "Too many failed access attempts are recorded for this account or repository. Wait 24 hours or ask the owner to review the local lockout. No request was executed.")
        return

    try:
        envelope = parse_envelope(body)
        payload = decrypt_payload(envelope)
    except FileNotFoundError:
        auth_response(number, "SETUP", "Phone-side password setup is incomplete. Ask the repository owner to run `terhux-auth-init.sh` in Termux. No request was executed.")
        return
    except (ValueError, json.JSONDecodeError, subprocess.TimeoutExpired, OSError):
        auth_response(number, "ENVELOPE", "The encrypted request could not be opened. Create a new request using the current public certificate; do not put the PIN in the issue body.")
        return

    pin = payload.pop("pin")
    if not verify_pin(pin):
        add_auth_failure(state, author)
        auth_response(number, "DENIED", "Access was not authorized. No request was executed. Ask the owner for the PIN privately; never post it in an issue or commit it to GitHub.")
        return
    clear_user_failures(author)

    try:
        request_id, command_text = validate_fields(payload["fields"])
    except (ValueError, KeyError, TypeError) as exc:
        auth_response(number, "REQUEST", f"The PIN was accepted, but the request format is invalid: {exc}. No action was executed.")
        return

    result_file = runner_result(request_id, command_text)
    # Do not acknowledge an unpublished result while offline; the next poll retries sync.
    sync = subprocess.run(["bash", str(REPO_DIR / "terhux-sync.sh")], cwd=REPO_DIR,
                          stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL, timeout=90, check=False)
    if sync.returncode:
        log(f"result for issue #{number} is local; GitHub sync will retry")
        return

    status, comment = summarize_result(request_id, result_file)
    marker = f"TERHUX_RESULT:{request_id}"
    if respond_once(number, marker, comment):
        close_issue(number)
    log(f"processed issue #{number} as {request_id}: {status}")


def main() -> int:
    if not (REPO_DIR / ".git").exists():
        log("repository unavailable; issue worker skipped")
        return 1
    try:
        listed = gh(["issue", "list", "--state", "open", "--label", LABEL,
                     "--limit", "1", "--search", "sort:created-asc",
                     "--json", "number,title,body,author"])
    except (OSError, subprocess.TimeoutExpired) as exc:
        log(f"issue poll failed: {type(exc).__name__}")
        return 1
    if listed.returncode:
        log(f"issue poll failed: gh exit {listed.returncode}")
        return 1
    try:
        issues = json.loads(listed.stdout)
    except (UnicodeDecodeError, json.JSONDecodeError):
        log("issue poll returned invalid JSON")
        return 1
    if not issues:
        return 0
    try:
        process_issue(issues[0])
    except (OSError, subprocess.TimeoutExpired, KeyError, ValueError) as exc:
        log(f"issue processing failed: {type(exc).__name__}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
