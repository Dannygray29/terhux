# Bitget Futures Bot — GitHub Cloud Scaffold

This project is stored in the private `Dannygray29/terhux` repository. It does not require project source files to be stored on the phone.

## Current scope
- GitHub is the source-code storage.
- GitHub Actions can run a manually triggered, read-only Bitget API connection check on a cloud runner.
- No orders, position changes, transfers, or withdrawals are implemented.
- Live automated trading is intentionally not implemented or enabled.
- Do not store credentials in files, commits, issue bodies, or chat.

## Configure GitHub Actions secrets
In the private repository, open **Settings → Secrets and variables → Actions → New repository secret** and add:
- `BITGET_API_KEY`
- `BITGET_API_SECRET`
- `BITGET_API_PASSPHRASE`

Use a dedicated Bitget API key with **read-only permissions only** for this test. Do not enable trading, transfers, or withdrawals. If IP allowlisting is required, note that GitHub-hosted runner IPs can change; do not weaken Bitget security just to make this workflow pass.

## Run the cloud connection check
Open **Actions → Bitget read-only connection check → Run workflow**. The workflow requests the Classic futures account list endpoint for `USDT-FUTURES` and reports only whether authentication succeeded and which margin coin types were returned. It does not print account balances or credentials.

Demo mode can be enabled by the workflow input. Confirm the appropriate API account type in Bitget before running. This checker targets the Classic v2 Mix endpoint; UTA accounts may require the UTA-specific API flow.

## Important runtime limitation
GitHub Actions is a cloud runner for bounded jobs, not an always-on process. It is suitable for this manual connectivity test and CI, but not for continuously managing live futures positions or guaranteeing stop-loss monitoring. A live bot would need a suitable always-on cloud runtime, secure secret injection, exchange-side protective orders, monitoring, and recovery logic. Do not run live trading until these are designed and tested.
