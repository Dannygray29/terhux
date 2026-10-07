#!/usr/bin/env python3
"""Create and verify a phone-local PIN verifier. PINs are read only from stdin."""
import hashlib
import hmac
import json
import os
import secrets
import sys
from pathlib import Path

N = 1 << 14
R = 8
P = 1
DKLEN = 32


def read_pin() -> bytes:
    pin = sys.stdin.buffer.read(256).strip()
    if not (4 <= len(pin) <= 64):
        raise ValueError("PIN must contain 4 to 64 bytes")
    return pin


def init_pin(path: Path) -> int:
    pin = read_pin()
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(pin, salt=salt, n=N, r=R, p=P, dklen=DKLEN)
    payload = {"algorithm": "scrypt", "n": N, "r": R, "p": P,
               "salt": salt.hex(), "digest": digest.hex()}
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload) + "\n", encoding="ascii")
    os.chmod(tmp, 0o600)
    tmp.replace(path)
    os.chmod(path, 0o600)
    return 0


def verify_pin(path: Path) -> int:
    pin = read_pin()
    try:
        config = json.loads(path.read_text(encoding="ascii"))
        salt = bytes.fromhex(config["salt"])
        expected = bytes.fromhex(config["digest"])
        n, r, p = int(config["n"]), int(config["r"]), int(config["p"])
        if config.get("algorithm") != "scrypt" or len(salt) != 16 or len(expected) != DKLEN:
            print("AUTH_SETUP_REQUIRED")
            return 2
        actual = hashlib.scrypt(pin, salt=salt, n=n, r=r, p=p, dklen=DKLEN)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
        print("AUTH_SETUP_REQUIRED")
        return 2
    if hmac.compare_digest(actual, expected):
        print("AUTH_OK")
        return 0
    print("AUTH_INVALID")
    return 1


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: terhux-auth.py <init-pin|verify-pin> <pin-hash-file>", file=sys.stderr)
        return 2
    command, file_path = sys.argv[1], Path(sys.argv[2])
    try:
        if command == "init-pin":
            return init_pin(file_path)
        if command == "verify-pin":
            return verify_pin(file_path)
    except (OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    print("unknown command", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
