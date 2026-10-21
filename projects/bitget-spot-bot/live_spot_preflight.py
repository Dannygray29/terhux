#!/usr/bin/env python3
"""Read-only Bitget spot preflight. This file has no order-placement calls."""
import os
import sys
from decimal import Decimal

try:
    import ccxt
except ImportError:
    print("ERROR: ccxt dependency missing")
    sys.exit(2)

KEY = os.getenv("BITGET_SPOT_API_KEY", "")
SECRET = os.getenv("BITGET_SPOT_API_SECRET", "")
PASSPHRASE = os.getenv("BITGET_SPOT_API_PASSPHRASE", "")
SYMBOL = os.getenv("BITGET_SPOT_SYMBOL", "BTC/USDT")
START = Decimal(os.getenv("START_BALANCE_USDT", "1.44"))
TARGET = Decimal(os.getenv("NET_PROFIT_TARGET_USDT", "0.05"))

if not all((KEY, SECRET, PASSPHRASE)):
    print("BLOCKED: required Bitget API secrets are missing.")
    sys.exit(2)
if START <= 0 or TARGET <= 0:
    print("BLOCKED: starting balance and profit target must be positive.")
    sys.exit(2)

exchange = ccxt.bitget({
    "apiKey": KEY, "secret": SECRET, "password": PASSPHRASE,
    "enableRateLimit": True, "options": {"defaultType": "spot"},
})
exchange.timeout = 15000

try:
    markets = exchange.load_markets()
    if SYMBOL not in markets:
        print(f"BLOCKED: {SYMBOL} is not listed as a spot market.")
        sys.exit(3)
    market = markets[SYMBOL]
    if not market.get("spot") or not market.get("active", True):
        print(f"BLOCKED: {SYMBOL} is not an active spot market.")
        sys.exit(3)

    balance = exchange.fetch_balance()
    free_usdt = Decimal(str((balance.get("free") or {}).get("USDT") or "0"))
    limits = market.get("limits") or {}
    amount_min = (limits.get("amount") or {}).get("min")
    cost_min = (limits.get("cost") or {}).get("min")
    price_value = exchange.fetch_ticker(SYMBOL).get("last")
    price = Decimal(str(price_value or "0"))

    fee = Decimal("0.001")  # rough illustration only; actual fee tier may differ
    gross_needed = TARGET / (Decimal("1") - fee * 2)
    round_trip_fee_est = (TARGET / (Decimal("1") - fee * 2)) * fee * 2

    print("BITGET SPOT PREFLIGHT — READ ONLY; NO ORDERS CAN BE PLACED")
    print("Authenticated account access: OK")
    print(f"Market: {SYMBOL}; active spot: OK")
    print(f"Available USDT: {free_usdt}")
    print(f"Minimum amount (exchange metadata): {amount_min if amount_min is not None else 'not reported'}")
    print(f"Minimum cost (exchange metadata): {cost_min if cost_min is not None else 'not reported'}")
    print(f"Last price: {price}")
    print(f"Reference starting balance: {START} USDT")
    print(f"Net profit target: {TARGET} USDT")
    print(f"Approximate gross target with assumed 0.1% each side: {gross_needed:.8f} USDT")
    print(f"Illustrative fee estimate on target-sized notional: {round_trip_fee_est:.8f} USDT")
    if free_usdt < START:
        print("WARNING: available USDT is below the reference starting balance.")
    if cost_min is not None and free_usdt < Decimal(str(cost_min)):
        print("BLOCKED FOR TRADING: available USDT is below the reported market minimum cost.")
    else:
        print("NO TRADE: this workflow is preflight-only.")
    print("A successful check does not authorize an order or imply a profitable strategy.")
except ccxt.AuthenticationError:
    print("BLOCKED: authentication rejected; check key, secret, passphrase, permissions, and IP restrictions.")
    sys.exit(4)
except ccxt.PermissionDenied:
    print("BLOCKED: API permission denied. Do not enable withdrawals or transfers.")
    sys.exit(4)
except ccxt.BaseError as exc:
    print(f"BLOCKED: exchange preflight failed ({type(exc).__name__}). No orders were placed.")
    sys.exit(5)
