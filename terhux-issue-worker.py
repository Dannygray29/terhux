#!/usr/bin/env python3
"""GitHub Issues mailbox for an AI-operated Termux shell."""
from __future__ import annotations

import base64
import fcntl
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

REPO_DIR = Path(os.environ.get("TERHUX_REPO_DIR", str(Path.home() / "terhux/repo"))).resolve()
DEFAULT_STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "terhux"
STATE_DIR = Path(os.environ.get("TERHUX_STATE_DIR", str(DEFAULT_STATE))).resolve()
COMMAND_DIR = STATE_DIR / "commands"
RESULT_DIR = STATE_DIR / "results"
LOCK_DIR = STATE_DIR / "locks"
LOG_DIR = STATE_DIR / "logs"
REPO_SLUG = os.environ.get("TERHUX_GITHUB_REPO", "Dannygray29/terhux")
LABEL = os.environ.get("TERHUX_REQUEST_LABEL", "terhux-request")
MAX_BODY_BYTES = 32_000
MAX_COMMENT_OUTPUT_BYTES = 30_000
ALLOWED_FIELDS = {
    "ACTION", "PROJECT", "PATH", "CONTENT_B64", "FROM_B64", "TO_B64",
    "PACKAGE", "NEW_NAME", "APPROVED",
}
ID_RE = re.compile(r"^issue-[1-9][0-9]*$")


def log(message: str) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (LOG_DIR / "bridge.log").open("a", encoding="utf-8") as stream:
        stream.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")


def gh(args: list[str], *, timeout: int = 30) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["gh", "--repo", REPO_SLUG, *args],
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
    return result.returncode == 0 and marker.encode("utf-8") in result.stdout


def respond_once(number: int, marker: str, body: str) -> bool:
    if not has_marker(number, marker) and not issue_comment(number, body):
        return False
    return True


def reject_issue(number: int, code: str, message: str) -> None:
    marker = f"TERHUX:{number}:{code}"
    if respond_once(number, marker, f"{marker}\n{message}"):
        remove_request_label(number)


def validate_request(body: str, issue_number: int) -> tuple[str, str]:
    """Accept raw shell text; retain the old structured JSON protocol for queued work."""
    encoded = body.encode("utf-8")
    if len(encoded) > MAX_BODY_BYTES:
        raise ValueError("request body exceeds 32 KB")
    if b"\x00" in encoded:
        raise ValueError("request contains a NUL byte")
    request_id = f"issue-{issue_number}"
    if not ID_RE.fullmatch(request_id):
        raise ValueError("invalid GitHub issue number")

    candidate = None
    if body.lstrip().startswith("{"):
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict) and ("ACTION" in parsed or "APPROVED" in parsed):
                candidate = parsed
        except json.JSONDecodeError:
            pass

    if candidate is not None:
        fields = candidate
        if not fields:
            raise ValueError("legacy request must be a non-empty JSON object")
        if any(not isinstance(key, str) for key in fields):
            raise ValueError("request field names must be strings")
        if set(fields) - ALLOWED_FIELDS:
            raise ValueError("legacy request contains unsupported fields")
        if any(not isinstance(value, str) or "\n" in value or "\r" in value or "\x00" in value
               for value in fields.values()):
            raise ValueError("legacy request values must be single-line strings")
        if not fields.get("ACTION"):
            raise ValueError("ACTION is required in a legacy JSON request")
        if fields.get("APPROVED") != "true":
            raise ValueError('APPROVED must be the string "true" in a legacy JSON request')
        command_fields = {"ID": request_id, **fields}
        command_text = "\n".join(f"{key}={command_fields[key]}" for key in sorted(command_fields)) + "\n"
        return request_id, command_text

    # Never execute issue prose/Markdown as shell. Raw shell requests must be
    # explicitly marked with TERHUX-SHELL-V1 on the first line.
    marker = "TERHUX-SHELL-V1\\n"
    if not body.startswith(marker):
        raise ValueError(
            "issue body is not an executable request. For a reviewed shell task, "
            "start the body with TERHUX-SHELL-V1 on its own line, followed by the command. "
            "Natural-language Markdown was not executed."
        )
    command = body[len(marker):]
    if not command.strip():
        raise ValueError("TERHUX-SHELL-V1 request has an empty command")
    command_b64 = base64.b64encode(command.encode("utf-8")).decode("ascii")
    command_text = (
        f"ID={request_id}\\n"
        "ACTION=shell-command\\n"
        f"COMMAND_B64={command_b64}\\n"
        "APPROVED=true\\n"
    )
    return request_id, command_text


def acquire_issue_lock(request_id: str):
    LOCK_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock_file = (LOCK_DIR / f"{request_id}.lock").open("a", encoding="utf-8")
    try:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock_file.close()
        return None
    return lock_file


def runner_result(request_id: str, command_text: str) -> Path:
    RESULT_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    result_file = RESULT_DIR / f"{request_id}.result"
    if result_file.exists():
        return result_file

    COMMAND_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    command_file = COMMAND_DIR / f"{request_id}.cmd"
    temp_command = COMMAND_DIR / f".{request_id}.{os.getpid()}.tmp"
    temp_command.write_text(command_text, encoding="utf-8")
    os.chmod(temp_command, 0o600)
    os.replace(temp_command, command_file)

    process = subprocess.Popen(
        ["bash", str(REPO_DIR / "terhux-runner.sh"), str(command_file)],
        cwd=REPO_DIR,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env=os.environ.copy(),
    )
    deadline = time.monotonic() + 1900
    while time.monotonic() < deadline:
        if result_file.is_file():
            return result_file
        if process.poll() is not None:
            break
        time.sleep(2)
    if not result_file.is_file():
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


def clip_utf8(text: str, max_bytes: int) -> tuple[str, bool]:
    raw = text.encode("utf-8", errors="replace")
    if len(raw) <= max_bytes:
        return text, False
    clipped = raw[:max_bytes].decode("utf-8", errors="ignore")
    return clipped + "\n[output clipped to fit the GitHub issue comment]", True


def markdown_code_block(text: str) -> str:
    # Disarm output lines that could close the fixed Markdown fence.
    safe = re.sub(
        r"(?m)^([ ]{0,3})(`{3,})",
        lambda match: f"{match.group(1)}{match.group(2)[:2]}\u200b{match.group(2)[2:]}",
        text,
    )
    return f"```text\n{safe.rstrip()}\n```"


def summarize_result(request_id: str, result_file: Path) -> tuple[str, str]:
    status, exit_code = "ERROR", "1"
    stdout_lines: list[str] = []
    stderr_lines: list[str] = []
    try:
        lines = result_file.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        lines = []
    for line in lines:
        if line.startswith("STATUS="):
            status = line.split("=", 1)[1]
        elif line.startswith("EXIT_CODE="):
            exit_code = line.split("=", 1)[1]

    def section(begin: str, end: str) -> list[str]:
        try:
            start = lines.index(begin) + 1
            stop = lines.index(end, start)
            return lines[start:stop]
        except ValueError:
            return []

    stdout_lines = section(f"STDOUT_BEGIN:{request_id}", f"STDOUT_END:{request_id}")
    stderr_lines = section(f"STDERR_BEGIN:{request_id}", f"STDERR_END:{request_id}")
    output_parts = []
    if stdout_lines:
        output_parts.append("\n".join(stdout_lines))
    if stderr_lines:
        detail = "\n".join(stderr_lines)
        if detail.strip():
            output_parts.append("stderr:\n" + detail)
    output = "\n\n".join(output_parts) if output_parts else "(no output)"
    output, _ = clip_utf8(output, MAX_COMMENT_OUTPUT_BYTES)
    marker = f"TERHUX_RESULT:{request_id}"
    comment = (
        f"{marker}\n"
        f"Status: `{status}` (exit code `{exit_code}`).\n\n"
        f"Output:\n{markdown_code_block(output)}"
    )
    return status, comment


def process_issue(issue: dict) -> None:
    number = int(issue["number"])
    body = str(issue.get("body") or "")
    if number < 1:
        return
    try:
        request_id, command_text = validate_request(body, number)
    except (ValueError, TypeError) as exc:
        reject_issue(number, "REQUEST", f"Invalid request: {exc}. No command was executed.")
        return

    lock_file = acquire_issue_lock(request_id)
    if lock_file is None:
        log(f"issue #{number} is already being handled by another worker")
        return
    try:
        started_marker = f"TERHUX_STARTED:{request_id}"
        if not respond_once(
            number,
            started_marker,
            f"{started_marker}\nTermux accepted this command and is executing it. This request uses the phone's Termux shell.",
        ):
            log(f"could not post start marker for issue #{number}; command not run")
            return

        result_file = runner_result(request_id, command_text)
        if not result_file.is_file():
            log(f"runner did not publish a result for issue #{number}; leaving it open for retry")
            return

        status, comment = summarize_result(request_id, result_file)
        if respond_once(number, f"TERHUX_RESULT:{request_id}", comment):
            close_issue(number)
        log(f"processed issue #{number} as {request_id}: {status}")
    finally:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        lock_file.close()


def main() -> int:
    if not (REPO_DIR / ".git").exists():
        log(f"repository unavailable: {REPO_DIR}")
        return 1
    try:
        listed = gh([
            "issue", "list", "--state", "open",
            "--label", LABEL,
            "--limit", "100", "--json", "number,title,body,labels",
        ])
    except (OSError, subprocess.TimeoutExpired) as exc:
        log(f"issue poll failed: {type(exc).__name__}")
        return 1
    if listed.returncode:
        detail = listed.stderr.decode("utf-8", errors="replace").strip()[:1200]
        log(f"issue poll failed: gh exit {listed.returncode}; stderr={detail}; repo={REPO_SLUG}; cwd={REPO_DIR}")
        return 1
    try:
        issues = json.loads(listed.stdout)
    except (UnicodeDecodeError, json.JSONDecodeError):
        log("issue poll returned invalid JSON")
        return 1
    if not isinstance(issues, list) or not issues:
        return 0

    requests = [
        issue for issue in issues
        if isinstance(issue, dict)
        and any(
            isinstance(label, dict) and label.get("name") == LABEL
            for label in (issue.get("labels") or [])
        )
    ]
    if not requests:
        return 0

    def queue_priority(issue: dict) -> tuple[int, int]:
        try:
            fields = json.loads(str(issue.get("body") or ""))
        except (json.JSONDecodeError, TypeError):
            fields = {}
        action = fields.get("ACTION") if isinstance(fields, dict) else None
        priority = 0 if action in {"terhux-runner-version", "terhux-runtime-status"} else 1
        return priority, int(issue.get("number", 0))

    requests.sort(key=queue_priority)
    try:
        process_issue(requests[0])
    except (OSError, subprocess.TimeoutExpired, KeyError, ValueError) as exc:
        log(f"issue processing failed: {type(exc).__name__}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
