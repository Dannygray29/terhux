#!/usr/bin/env python3
"""LIVE-account connectivity and order-feasibility check ONLY.

This module intentionally contains no create_order call and cannot place trades.
It checks authenticated spot access, balances, and current exchange market limits.
"""
import os
import sys
from decimal import Decimal

try:
    import ccxt
except ImportError:
    print("ERROR: ccxt dependency missing")
    sys.exit(2)

API_KEY = os.getenv("BITGET_SPOT_API_KEY", "")
API_SECRET = os.getenv("BITGET_SPOT_API_SECRET", "")
API_PASSPHRASE = os.getenv("BITGET_SPOT_API_PASSPHRASE", "")
SYMBOL = os.getenv("BITGET_SPOT_SYMBOL", "BTC/USDT")
START_BALANCE = Decimal(os.getenv("START_BALANCE_USDT", "1.44"))
NET_TARGET = Decimal(os.getenv("NET_PROFIT_TARGET_USDT", "0.05"))

if not all((API_KEY, API_SECRET, API_PASSPHRASE)):
    print("BLOCKED: add BITGET_SPOT_API_KEY, BITGET_SPOT_API_SECRET and BITGET_SPOT_API_PASSPHRASE as GitHub Actions secrets.")
    sys.exit(2)
if START_BALANCE <= 0 or NET_TARGET <= 0:
    print("BLOCKED: starting balance and profit target must be positive.")
    sys.exit(2)

exchange = ccxt.bitget({
    "apiKey": API_KEY,
    "secret": API_SECRET,
    "password": API_PASSPHRASE,
    "enableRateLimit": True,
    "options": {"defaultType": "spot"},
})
exchange.timeout = 15000

try:
    # Read-only calls only: market metadata and authenticated account balance.
    markets = exchange.load_markets()
    if SYMBOL not in markets:
        print(f"BLOCKED: {SYMBOL} is not an available spot market for this API/account.")
        sys.exit(3)
    market = markets[SYMBOL]
    if not market.get("spot") or not market.get("active", True):
        print(f"BLOCKED: {SYMBOL} is not an active spot market.")
        sys.exit(3)

    balance = exchange.fetch_balance()
    free_usdt = Decimal(str((balance.get("free") or {}).get("USDT") or "0"))
    limits = market.get("limits") or {}
    amount_limits = limits.get("amount") or {}
    cost_limits = limits.get("cost") or {}
    min_amount = Decimal(str(amount_limits.get("min") or "0"))
    min_cost = Decimal(str(cost_limits.get("min") or "0"))
    price = Decimal(str(exchange.fetch_ticker(SYMBOL).get("last") or "0"))

    # Conservative standard-fee estimate only; actual account tier, spread,
    # slippage, fee currency and execution price can differ.
    assumed_fee = Decimal("0.001")
    gross_needed = NET_TARGET / (Decimal("1") - Decimal("2") * assumed_fee)
    estimated_cost = gross_needed / (Decimal("1") + assumed_fee)
    estimated_fee_round_trip = estimated_cost * assumed_fee * 2

    print("LIVE SPOT PREFLIGHT — READ ONLY; NO ORDERS CAN BE PLACED")
    print(f"Authenticated account access: OK")
    print(f"Market: {SYMBOL}; active spot market: OK")
    print(f"Available USDT: {free_usdt}")
    print(f"Market minimum amount: {min_amount or 'not supplied by exchange metadata'}")
    print(f"Market minimum cost: {min_cost or 'not supplied by exchange metadata'}")
    print(f"Last price: {price}")
    print(f"Configured starting-balance reference: {START_BALANCE} USDT")
    print(f"Net profit target: {NET_TARGET} USDT")
    print(f"Approximate gross profit required with assumed 0.1% fee each side: {gross_needed:.8f} USDT")
    print(f"Approximate round-trip fee on target-sized notional: {estimated_fee_round_trip:.8f} USDT")
    if free_usdt < START_BALANCE:
        print("WARNING: available USDT is below the configured starting-balance reference.")
    if min_cost and free_usdt < min_cost:
        print("BLOCKED FOR TRADING: available USDT is below this market's reported minimum cost.")
    else:
        print("NO TRADE: this workflow is preflight-only. Feasibility checks do not authorize or place an order.")
    print("NEXT GATE: independently review order sizing, spread/slippage, fees, stop/exit logic and loss caps before implementing any live order path.")
except ccxt.AuthenticationError:
    print("BLOCKED: Bitget rejected authentication. Check API key, secret, passphrase, account permissions and IP restrictions.")
    sys.exit(4)
except ccxt.PermissionDenied:
    print("BLOCKED: API permission denied. Use read/account access for this preflight; do not enable withdrawals or transfers.")
    sys.exit(4)
except ccxt.BaseError as exc:
    print(f"BLOCKED: exchange preflight failed ({type(exc).__name__}). No orders were placed.")
    sys.exit(5)
