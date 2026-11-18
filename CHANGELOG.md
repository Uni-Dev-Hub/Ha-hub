# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-11-19

First stable release. Highlights over the beta: real card-style dashboard with
live layout preview, entity pickers with domain/area filters, per-channel
display of multi-gang devices, built-in localization (9 languages, instant
switching from settings) and hardened connection handling.

### Added
- CI workflow: JS unit tests, package metadata validation and `.plasmoid` build artifacts (GitHub Actions).
- Release workflow: pushing a `v<version>` tag builds the `.plasmoid` and publishes a GitHub Release.
- `scripts/make-plasmoid.sh` and `tests/run_qml_tests.sh` helpers.
- Reconnection with exponential backoff (2s … 60s) and a watchdog that resets half-open WebSocket connections when no data arrives for 90s.
- The "Connect on startup" (autoConnect) setting is now actually respected.
- New unit tests for entity helpers, WebSocket payloads and the device catalog (including QML tests for catalog updates via `state_changed` and pending-request cleanup).

### Changed
- The access token is now stored in a single place (the widget's shared private storage) and is removed from Plasma's config file (`plasmarc`) once persisted. Direct KWallet access is not possible from pure-QML applets on Plasma 6 (no QML API exists; tracked for a future C++ extension).
- All WebSocket requests (`get_states`, registries, `call_service`) are dispatched through per-request callbacks; concurrent registry refreshes can no longer overwrite each other's message ids.
- Device catalog titles now refresh immediately when a friendly name changes through `state_changed` events, and removed entities are dropped from the catalog right away.
- Default HA host is `homeassistant.local` instead of a hard-coded LAN IP.
- Port setting is stored as an integer (validated 1–65535) instead of a free-form string.
- Control-domain list is defined once in `ha_helpers.js` and reused by the manager.

### Fixed
- Dashboard cards failed to load at runtime (broken relative import of `ha_helpers.js`, unsupported padding properties on a plain `Item`), which cascaded into "Type X unavailable" errors across the whole popup.
- Access-token hint in General settings used a `Kirigami.FormData` property that does not exist in Kirigami 6 and prevented the settings page from loading.
- New link test (`tests/qml/tst_imports.qml`) and CI check (`scripts/check_imports.py`) guard against these class of errors.
- QML unit tests crashed outside the Plasma shell because the `i18n()` global was not available in `HAManager.qml`.
- Pending request callbacks were never released when the connection dropped, leaking handlers and leaving UI spinners stuck.

### Removed
- Unused configuration keys `panelDisplayMode` and `primarySensorEntity`.
- Empty placeholder file `contents/code/template_engine.js`.

## [1.0.0-beta1]

- Initial public beta: real-time Home Assistant WebSocket sync, mDNS-style auto-probing,
  15+ device domains, favorites manager and dashboard concept.
