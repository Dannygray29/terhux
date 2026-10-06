# NetBoost
NetBoost is an Android-first network diagnostics app. It measures connection experience and explains likely causes without pretending to increase ISP bandwidth.

## What works
- HTTPS latency and jitter sampling
- request-failure packet-loss estimate
- DNS-over-HTTPS response timing
- real download throughput measurement
- real upload throughput measurement when the endpoint permits it
- quality score and rule-based explanations
- local history (up to 100 tests)
- privacy/limitations screen
- Capacitor packaging configuration

## What it cannot do
It cannot increase ISP bandwidth, bypass carrier restrictions, or provide true ICMP-level packet-loss measurements from a browser WebView. Android radio/SSID details can also be restricted.

## Development
Requires Node.js 22+ for current Capacitor. npm install, npm run build, npm test.

## Android
npm run cap:sync creates/synchronizes web assets with Capacitor. Then npx cap add android can be used when the Android SDK/build environment is available.

## Privacy
See PRIVACY.md.