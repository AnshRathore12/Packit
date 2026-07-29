# Changelog

All notable changes to **Packit** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-07-29

### Added

- **Network Inspector** — Intercept, browse, and inspect every HTTP/HTTPS request and response in real time.
  - Automatic URL session interception via `Packit.startIntercepting()`
  - Detailed transaction view with headers, body (JSON viewer), timing, and status codes
  - Fuzzy search across captured requests
  - cURL export for any captured request
  - One-tap copy of entire JSON request/response bodies
  - JWT token decoder
  - HTML response preview
  - Share sheet for exporting transactions
- **Overlay Mode** — Draggable floating button (`.withNetworkInspectorOverlay()`) that opens Packit from anywhere in your app.
- **PackitView** — Drop-in SwiftUI view for embedding the inspector into a custom tab or navigation flow.
- **Automatic Release Safety** — All APIs are no-ops in release builds. No `#if DEBUG` wrappers needed.
