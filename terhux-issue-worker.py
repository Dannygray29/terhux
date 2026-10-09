#!/usr/bin/env python3
"""Consume structured GitHub Issues for the phone-hosted Terhux bridge."""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

REPO_DIR = Path(os.environ.get("TERHUX_REPO_DIR", str(Path.home() / "terhux/repo"))).resolve()
REPO_SLUG = os.environ.get("TERHUX_GITHUB_REPO", "Dannygray29/terhux")
LABEL = os.environ.get("TERHUX_REQUEST_LABEL", "terhux-request")
MAX_BODY_BYTES = 32_000
ALLOWED_FIELDS = {
    "ACTION", "PROJECT", "PATH", "CONTENT_B64", "FROM_B64", "TO_B64",
    "PACKAGE", "NEW_NAME", "APPROVED",
}
ID_RE = re.compile(r"^issue-[1-9][0-9]*$")


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
    return result.returncode == 0 and marker.encode("utf-8") in result.stdout


def respond_once(number: int, marker: str, body: str) -> bool:
    if not has_marker(number, marker):
        if not issue_comment(number, body):
            return False
    return True


def reject_issue(number: int, code: str, message: str) -> None:
    marker = f"TERHUX:{number}:{code}"
    if respond_once(number, marker, f"{marker}\n{message}"):
        remove_request_label(number)


def validate_request(body: str, issue_number: int) -> tuple[str, str]:
    if len(body.encode("utf-8")) > MAX_BODY_BYTES:
        raise ValueError("request body exceeds 32 KB")
    try:
        fields = json.loads(body)
    except json.JSONDecodeError as exc:
        raise ValueError("issue body must be one JSON object without Markdown fences") from exc
    if not isinstance(fields, dict) or not fields:
        raise ValueError("request must be a non-empty JSON object")
    if any(not isinstance(key, str) for key in fields):
        raise ValueError("request field names must be strings")
    if set(fields) - ALLOWED_FIELDS:
        raise ValueError("request contains unsupported fields")
    if any(not isinstance(value, str) or "\n" in value or "\r" in value or "\x00" in value
           for value in fields.values()):
        raise ValueError("all request values must be single-line strings")
    if not fields.get("ACTION"):
        raise ValueError("ACTION is required")
    if fields.get("APPROVED") != "true":
        raise ValueError('APPROVED must be the string "true"')

    request_id = f"issue-{issue_number}"
    if not ID_RE.fullmatch(request_id):
        raise ValueError("invalid GitHub issue number")
    command_fields = {"ID": request_id, **fields}
    command_text = "\n".join(f"{key}={command_fields[key]}" for key in sorted(command_fields)) + "\n"
    return request_id, command_text


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
    return status, (
        f"TERHUX_RESULT:{request_id}\n"
        f"Request finished with status **{status}** (exit `{exit_code}`).\n"
        f"Result: {url}"
    )


def process_issue(issue: dict) -> None:
    number = int(issue["number"])
    title = str(issue.get("title") or "")
    body = str(issue.get("body") or "")

    if number < 1:
        return
    if not title.startswith("[Terhux]"):
        reject_issue(number, "TITLE", "Request titles must start with `[Terhux]`. No action was executed.")
        return
    try:
        request_id, command_text = validate_request(body, number)
    except (ValueError, TypeError) as exc:
        reject_issue(number, "REQUEST", f"Invalid request: {exc}. No action was executed.")
        return

    result_file = runner_result(request_id, command_text)
    if not result_file.is_file():
        log(f"runner did not publish a result for issue #{number}; leaving it queued for retry")
        return

    # Do not acknowledge an unpublished result while offline; the next poll retries sync.
    try:
        sync = subprocess.run(
            ["bash", str(REPO_DIR / "terhux-sync.sh")],
            cwd=REPO_DIR,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=90,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        log(f"result for issue #{number} is local; sync will retry ({type(exc).__name__})")
        return
    if sync.returncode:
        log(f"result for issue #{number} is local; GitHub sync will retry")
        return

    status, comment = summarize_result(request_id, result_file)
    if respond_once(number, f"TERHUX_RESULT:{request_id}", comment):
        close_issue(number)
    log(f"processed issue #{number} as {request_id}: {status}")


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
        log(f"issue poll failed: gh exit {listed.returncode}")
        return 1
    try:
        issues = json.loads(listed.stdout)
    except (UnicodeDecodeError, json.JSONDecodeError):
        log("issue poll returned invalid JSON")
        return 1
    if not isinstance(issues, list) or not issues:
        return 0
    # The label is the queue authorization gate. Never let unrelated or
    # rejected issues block later requests merely because their title matches.
    requests = [
        issue for issue in issues
        if isinstance(issue, dict)
        and str(issue.get("title") or "").startswith("[Terhux]")
        and any(
            isinstance(label, dict) and label.get("name") == LABEL
            for label in (issue.get("labels") or [])
        )
    ]
    if not requests:
        return 0
    requests.sort(key=lambda issue: int(issue.get("number", 0)))
    try:
        process_issue(requests[0])
    except (OSError, subprocess.TimeoutExpired, KeyError, ValueError) as exc:
        log(f"issue processing failed: {type(exc).__name__}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
