# Bitget Spot Bot

A dedicated spot-trading project inside the private `Dannygray29/terhux` repository, separate from the futures demo bot.

## Current safety stage

**Preflight only — no order placement is implemented.** The workflow checks live API authentication, available USDT, spot-market metadata, ticker price, and reported minimum amount/cost. A successful preflight does not authorize trading or prove any strategy is profitable.

- Reference starting balance: 1.44 USDT
- First net-profit target: 0.05 USDT
- Market: spot only
- Risk mode: preserve balance; skip trades that fail minimums or risk limits

The target is not guaranteed. Fees, spread, slippage, minimum order sizes, and price movements can make trading impractical with this balance. The preflight uses a rough 0.1% per-side fee assumption for illustration only.

## Run the read-only preflight

1. Add GitHub Actions secrets:
   - `BITGET_SPOT_API_KEY`
   - `BITGET_SPOT_API_SECRET`
   - `BITGET_SPOT_API_PASSPHRASE`
2. Use a live Bitget key with only required read/account permissions for preflight. Do not enable withdrawals or transfers. Use IP restrictions where practical, noting hosted runner IPs can change.
3. Open **Actions → Bitget Spot Bot preflight (read-only) → Run workflow** and choose a spot pair in CCXT format, default `BTC/USDT`.
4. Review the actual run logs. Never paste API credentials into chat, code, issues, or logs.

## Before any live order can be added

A separate implementation and review must validate exchange order constraints, fee tier, spread/slippage, order sizing, exits, a loss cap, duplicate-order prevention, and a kill switch. Live order placement must remain disabled until account connection and parameters are validated and the user explicitly authorizes the specific order. Never claim an unverified trade succeeded.

GitHub Actions is a short-lived workflow runner, not an always-on trading service.
