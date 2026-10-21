# Bitget Futures Bot — GitHub Cloud Project

All source code and cloud-run configuration live in this private repository. No project source files need to be stored on the phone.

## Staged rollout

1. **Market analysis and signals:** fetch public Bitget futures candles and calculate a simple EMA crossover signal.
2. **Demo trading:** use a Bitget Demo API key and the `paptrading: 1` header. The workflow defaults to signals only; demo order placement requires deliberately enabling its workflow input.
3. **Live spot preparation:** a separate **read-only preflight** validates live API authentication, available USDT, and current spot-market limits. It cannot place orders. Live trading is NOT enabled.

## Live spot preflight (read-only)

Open [Bitget LIVE spot preflight](../../actions/workflows/bitget-live-spot-preflight.yml) and select **Run workflow**. Default market is `BTC/USDT`. Add these repository Actions secrets first:

- `BITGET_SPOT_API_KEY`
- `BITGET_SPOT_API_SECRET`
- `BITGET_SPOT_API_PASSPHRASE`

Create a **live** Bitget API key with only the minimum read/account permissions needed for the preflight. Do not enable withdrawals or transfers. Use IP restrictions where practical; GitHub-hosted runner IPs can change. Never put keys in code, commits, issue comments, logs, or chat.

The script `live_spot_preflight.py` makes read-only market, ticker and balance requests. It has **no order-placement call**. It will not buy or sell anything. A successful preflight only confirms the connection and reports current constraints; it does not validate that a profitable strategy exists or authorize future live orders.

Your configured goal is to grow a reference balance of **1.44 USDT** toward a **0.05 USDT net-profit target**. This is a target, not a promise. Spot trading fees, spread, slippage, minimum order sizes, and price movements can make the target impractical for this balance. The checker uses a rough 0.1% fee assumption for illustration; your account's actual fee tier may differ. Bitget says spot minimum sizes vary by pair and the default spot fee is 0.1% per side; check the current account fee tier and market rules before any future order. See [Bitget spot limits and fee guidance](https://www.bitget.com/asia/support/articles/12560603820584).

## Demo workflow

Open [Bitget demo analysis and trading](../../actions/workflows/bitget-demo-bot.yml). Defaults:
- Demo mode only.
- `BTCUSDT`, `USDT-FUTURES`, 1-minute candles.
- Demo order placement disabled until you explicitly turn on the workflow input.
- Use only dedicated demo API credentials for demo orders.

For market analysis alone, no API key is required. To place demo orders, add:
- `BITGET_DEMO_API_KEY`
- `BITGET_DEMO_API_SECRET`
- `BITGET_DEMO_API_PASSPHRASE`

Bitget's official demo API instructions require a Demo API key and the `paptrading: 1` request header. See [Bitget Demo Trading API docs](https://www.bitget.com/docs/uta/demo-trading/rest-api).

## Safety limits and limitations

- The starter futures strategy is a basic EMA(9)/EMA(21) crossover demonstration, not a profitable-strategy claim or financial advice.
- Demo orders are market orders with a small configurable size. They are not a complete strategy and do not provide a guaranteed stop loss.
- The GitHub Actions workflows are bounded cloud jobs, not always-on trading infrastructure.
- No live order endpoint or live-trading workflow is included. Do not simply change a demo flag to trade real funds. A future live stage would require separate implementation, independent review, strict sizing/fee/spread checks, loss caps, exit handling, a kill switch and explicit authorization.
- This code targets Bitget Classic v2 Mix futures APIs for the existing futures demo. UTA accounts may use a different API flow.

## Existing read-only futures checker

`connect_readonly.py` remains available for a read-only Classic v2 account authentication test. It is not proof of a successful connection until you run it and inspect the workflow result.
