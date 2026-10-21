"""Read-only Bitget Classic v2 futures API check. Never submits orders."""
import base64
import hashlib
import hmac
import json
import os
import sys
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

BASE_URL = "https://api.bitget.com"
PATH = "/api/v2/mix/account/accounts"

def main() -> int:
    key = os.environ.get("BITGET_API_KEY", "").strip()
    secret = os.environ.get("BITGET_API_SECRET", "").strip()
    passphrase = os.environ.get("BITGET_API_PASSPHRASE", "").strip()
    product_type = os.environ.get("BITGET_PRODUCT_TYPE", "USDT-FUTURES").strip()
    demo = os.environ.get("BITGET_DEMO", "true").strip().lower() in {"1", "true", "yes", "on"}

    if not all((key, secret, passphrase)):
        print("FAILED: Required GitHub Actions secrets are missing.")
        return 2
    if product_type not in {"USDT-FUTURES", "COIN-FUTURES", "USDC-FUTURES"}:
        print("FAILED: Unsupported product type.")
        return 2

    query = urlencode({"productType": product_type})
    timestamp = str(int(time.time() * 1000))
    request_path = PATH + "?" + query
    prehash = timestamp + "GET" + request_path
    signature = base64.b64encode(
        hmac.new(secret.encode("utf-8"), prehash.encode("utf-8"), hashlib.sha256).digest()
    ).decode("ascii")

    headers = {
        "ACCESS-KEY": key,
        "ACCESS-SIGN": signature,
        "ACCESS-TIMESTAMP": timestamp,
        "ACCESS-PASSPHRASE": passphrase,
        "Content-Type": "application/json",
        "locale": "en-US",
    }
    if demo:
        headers["paptrading"] = "1"

    request = Request(BASE_URL + request_path, headers=headers, method="GET")
    try:
        with urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        # Do not print response bodies or headers; they can contain sensitive details.
        print("FAILED: Bitget returned HTTP status", exc.code)
        return 3
    except (URLError, TimeoutError, json.JSONDecodeError):
        print("FAILED: Network, timeout, or response parsing error.")
        return 4

    if payload.get("code") != "00000":
        print("FAILED: Bitget rejected the read-only request. Check API account type, permissions, passphrase, demo/live mode, IP allowlist, and clock.")
        return 5

    rows = payload.get("data")
    if not isinstance(rows, list):
        print("FAILED: Unexpected response shape.")
        return 6
    coins = sorted({str(row.get("marginCoin", "unknown")) for row in rows if isinstance(row, dict)})
    print("SUCCESS: Bitget read-only API authentication worked.")
    print("Environment:", "DEMO" if demo else "LIVE READ-ONLY")
    print("Product type:", product_type)
    print("Margin coin types returned:", ", ".join(coins) if coins else "none")
    print("No balances, API credentials, orders, or positions were printed or changed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
