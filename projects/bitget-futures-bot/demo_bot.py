"""Bitget Classic v2 USDT futures EMA crossover demo bot.

Market analysis uses public data. Optional order placement is hard-wired to the
Bitget demo environment via paptrading=1. This module has no live-trading mode.
"""
import base64
import hashlib
import hmac
import json
import os
import sys
import time
import uuid
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BASE_URL = "https://api.bitget.com"
CANDLES_PATH = "/api/v2/mix/market/candles"
ORDER_PATH = "/api/v2/mix/order/place-order"


def request_json(method, path, body=None, signed=False):
    body_text = json.dumps(body, separators=(",", ":")) if body is not None else ""
    headers = {"Content-Type": "application/json", "locale": "en-US"}
    if signed:
        key = os.environ.get("BITGET_API_KEY", "").strip()
        secret = os.environ.get("BITGET_API_SECRET", "").strip()
        passphrase = os.environ.get("BITGET_API_PASSPHRASE", "").strip()
        if not all((key, secret, passphrase)):
            raise RuntimeError("Demo API secrets are missing; no order was sent.")
        timestamp = str(int(time.time() * 1000))
        prehash = timestamp + method.upper() + path + body_text
        sign = base64.b64encode(
            hmac.new(secret.encode(), prehash.encode(), hashlib.sha256).digest()
        ).decode()
        headers.update({
            "ACCESS-KEY": key,
            "ACCESS-SIGN": sign,
            "ACCESS-TIMESTAMP": timestamp,
            "ACCESS-PASSPHRASE": passphrase,
            "paptrading": "1",
        })
    request = Request(BASE_URL + path, data=body_text.encode() if body is not None else None,
                      headers=headers, method=method.upper())
    try:
        with urlopen(request, timeout=20) as response:
            result = json.loads(response.read().decode())
    except HTTPError as exc:
        raise RuntimeError("Bitget returned HTTP status " + str(exc.code)) from None
    except (URLError, TimeoutError, json.JSONDecodeError):
        raise RuntimeError("Network, timeout, or response parsing error") from None
    if not isinstance(result, dict) or result.get("code") != "00000":
        raise RuntimeError("Bitget API rejected the request; check API version, symbol, permissions, and demo key.")
    return result


def ema(values, period):
    alpha = 2 / (period + 1)
    current = values[0]
    output = [current]
    for value in values[1:]:
        current = alpha * value + (1 - alpha) * current
        output.append(current)
    return output


def main():
    # Deliberately no live mode: every private order request carries paptrading=1.
    if os.environ.get("BITGET_DEMO", "").lower() != "true":
        print("BLOCKED: This bot only supports Bitget demo mode.")
        return 2

    symbol = os.environ.get("BITGET_SYMBOL", "BTCUSDT").strip().upper()
    product = os.environ.get("BITGET_PRODUCT_TYPE", "USDT-FUTURES").strip()
    if product != "USDT-FUTURES" or not symbol or len(symbol) > 30:
        print("FAILED: This demo build supports USDT-FUTURES only; check the symbol.")
        return 2

    query = urlencode({"symbol": symbol, "productType": product, "granularity": "1m", "limit": "100"})
    candles = request_json("GET", CANDLES_PATH + "?" + query).get("data")
    if not isinstance(candles, list) or len(candles) < 30:
        print("FAILED: Not enough candle data to calculate the signal.")
        return 3

    try:
        ordered = sorted(candles, key=lambda row: int(row[0]))
        closes = [float(row[4]) for row in ordered if isinstance(row, list) and len(row) >= 5]
    except (ValueError, TypeError, IndexError):
        print("FAILED: Unexpected candle data.")
        return 3
    if len(closes) < 30 or any(value <= 0 for value in closes):
        print("FAILED: Invalid candle close prices.")
        return 3

    fast = ema(closes, 9)
    slow = ema(closes, 21)
    previous_difference = fast[-2] - slow[-2]
    current_difference = fast[-1] - slow[-1]
    signal = "HOLD"
    if previous_difference <= 0 and current_difference > 0:
        signal = "BUY"
    elif previous_difference >= 0 and current_difference < 0:
        signal = "SELL"

    print("Mode: DEMO ONLY")
    print("Symbol:", symbol, "| Product:", product)
    print("Latest close:", format(closes[-1], ".8f"))
    print("EMA(9):", format(fast[-1], ".8f"), "| EMA(21):", format(slow[-1], ".8f"))
    print("Signal:", signal, "(EMA crossover demonstration; not a profitability claim)")

    enabled = os.environ.get("ENABLE_DEMO_ORDERS", "false").strip().lower() in {"1", "true", "yes", "on"}
    if signal == "HOLD" or not enabled:
        print("Order placement: skipped (no crossover or demo orders disabled).")
        return 0

    try:
        size = float(os.environ.get("BITGET_ORDER_SIZE", "0.001").strip())
        if not (0 < size <= 0.001):
            print("BLOCKED: Demo order size must be greater than 0 and no more than 0.001.")
            return 4
    except ValueError:
        print("BLOCKED: Invalid demo order size.")
        return 4

    order = {
        "symbol": symbol,
        "productType": product,
        "marginMode": "isolated",
        "marginCoin": "USDT",
        "size": format(size, ".8f").rstrip("0").rstrip("."),
        "side": "buy" if signal == "BUY" else "sell",
        "orderType": "market",
        "force": "gtc",
        "clientOid": "grey-demo-" + uuid.uuid4().hex[:20],
    }
    result = request_json("POST", ORDER_PATH, order, signed=True)
    data = result.get("data")
    if isinstance(data, dict) and data.get("orderId"):
        print("DEMO ORDER ACCEPTED by Bitget. Order ID:", str(data["orderId"]))
        print("This is a virtual demo order, not a live trade.")
    else:
        print("Request accepted but no order ID was returned; verify it in Bitget Demo Trading.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as exc:
        print("FAILED:", str(exc))
        sys.exit(5)
