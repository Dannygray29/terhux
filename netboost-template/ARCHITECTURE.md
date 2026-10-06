# Architecture
UI is React + TypeScript. The measurement engine is isolated in src/engine/measure.ts; diagnostic rules are isolated in src/engine/diagnostics.ts; persistence is isolated in src/storage/history.ts.

Capacitor provides the Android shell and native bridge. The app currently uses standards-based network measurements so the same engine can run on web/PWA. Native Android integrations can be added behind the same interfaces later.

No backend or database is required for core functionality.