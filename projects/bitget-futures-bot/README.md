# Bitget Futures Bot — GitHub Cloud Project

All source code and cloud-run configuration live in this private repository. No project source files need to be stored on the phone.

## Staged rollout

1. **Market analysis and signals:** fetch public Bitget futures candles and calculate a simple EMA crossover signal.
2. **Demo trading:** use a Bitget Demo API key and the `paptrading: 1` header. The workflow defaults to signals only; demo order placement requires deliberately enabling its workflow input.
3. **Live trading:** intentionally NOT enabled in this version. It requires a separate reviewed implementation, explicit live credentials, strict risk limits, exchange-side protective orders, monitoring, and an always-on host. Do not point demo credentials at live endpoints or reuse a demo workflow for live trading.

## Cloud workflow

Open [Actions](../../actions/workflows/bitget-demo-bot.yml) and run **Bitget demo analysis and trading**. Defaults:
- Demo mode only.
- `BTCUSDT`, `USDT-FUTURES`, 1-minute candles.
- Demo order placement disabled until you explicitly turn on the workflow input.
- No secret values or account balances are printed.

For market analysis alone, no API key is required. To place demo orders, add these repository Actions secrets:
- `BITGET_DEMO_API_KEY`
- `BITGET_DEMO_API_SECRET`
- `BITGET_DEMO_API_PASSPHRASE`

Create the key while in Bitget Demo Trading and use it only for demo trading. Bitget's official demo API instructions require a Demo API key and the `paptrading: 1` request header. See [Bitget Classic Demo Trading API docs](https://www.bitget.com/docs/classic/demo-trading/rest-api).

## API permissions

- Analysis/signals: public market data only; no private key needed.
- Demo order placement: use a dedicated demo API key with only the minimum permissions needed for demo trading.
- Future live phase: a separate API key with trading permission only if/when intentionally enabled. **Never enable withdrawal or transfer permission.** Bind the key to a trusted fixed IP where supported. GitHub-hosted runner IPs can change, so a fixed-IP cloud host is preferable before any live use.
- Never put keys in code, commits, issue comments, logs, or chat. Use GitHub Actions Secrets.

## Safety limits and limitations

- This starter strategy is a basic EMA(9)/EMA(21) crossover demonstration, not a profitable-strategy claim or financial advice.
- Demo orders are market orders with a small configurable size. They are not a complete strategy and do not provide a guaranteed stop loss. Keep demo order placement off until you've reviewed the symbol, quantity, and API account type.
- The workflow is a bounded cloud job, not an always-on trading server. It cannot guarantee continuous monitoring or protective-order handling.
- No live order endpoint or live-trading workflow is included. A future live stage must be implemented separately and reviewed; do not simply change a demo flag to trade real funds.
- This code targets Bitget **Classic v2 Mix** futures APIs. Bitget recommends checking the account-specific documentation; UTA accounts use a different API flow.

## Existing read-only checker

`connect_readonly.py` remains available for a read-only Classic v2 account authentication test. It is not proof of a successful connection until you run it and inspect the workflow result.
