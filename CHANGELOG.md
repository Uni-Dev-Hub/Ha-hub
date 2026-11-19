# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] - 2026-11-19

Focus of this release: dashboard tile groups in the Metro style, entity names
exactly as Home Assistant shows them, a new "Appearance" settings page (header
avatar and entity, tray icon, which views are shown) and settings pickers that
fit into the popup.

### Added
- New "Appearance" settings page: choose which views the popup shows (Dashboard
  and/or Devices), which Home Assistant person provides the header picture and
  which entity value is displayed next to the greeting (with a live preview).
  With only one view enabled the switch button between them is hidden and the
  popup opens that view directly.
- Header: round user picture from Home Assistant (the `entity_picture` of the
  selected person) and a configurable entity value, e.g. `-3.5 °C`. The picture
  falls back to the identity icon when the person has none or it cannot be
  loaded.

### Changed
- Entity names are taken from the entity's friendly name — the same text Home
  Assistant itself shows — instead of the short name stored in the entity
  registry, which lost the device prefix ("Light" instead of "Corridor Light").
- The header no longer shows the version badge; the user picture from Home
  Assistant and a configurable entity (e.g. a temperature sensor) are shown
  there instead.
- Entity pickers in settings filter entity types through a drop-down list with
  counts; the row of buttons did not fit into the settings dialog.

### Fixed
- Multi-channel rows only append a disambiguating suffix when two channels of
  the same device really share a name.

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
- Dashboard cards are real cards now: shadowed panel that lifts on hover, entity icon on a state-tinted tile, live status and time since the last state change.
- Dashboard grid options: 2/3/4 columns, compact or normal card density, per-card 1x1/2x1/1x2/2x2 size and a live layout preview in Settings → Dashboard that reuses the actual dashboard view.
- Shared filter strip in the Favorite Devices and Dashboard pickers: search, entity-type chips with counts and an area picker (`EntityFilterBar`).
- Localization for 9 languages (English, Russian, Kazakh, Ukrainian, German, Spanish, French, Turkish, Chinese) with instant switching in Settings → General; "System language" is the default and untranslated strings fall back to English.
- Tests for the translation catalogs (key and placeholder parity across all languages, language routing through the helpers) and for release metadata (version matches `metadata.json` and the changelog).
- QML tests that instantiate the settings pages (card rows, ordering and resize, shared filter bar) and the dashboard empty state, so a broken page shows up as a failing test instead of a blank popup; `scripts/check_imports.py` additionally verifies that every file using `Loc` imports the l10n module.

### Changed
- Multi-gang devices (switches, covers, climate zones…) list every control entity as its own object — "Corridor • Light", "Corridor • Toilet" — instead of hiding the extra channels behind the primary one.
- Helper scripts are ES modules (`contents/code/ha_helpers.mjs`): Qt 6 cannot parse `import` statements inside `.js` QML scripts, so shared code must use `.mjs`.
- The access token is now stored in a single place (the widget's shared private storage) and is removed from Plasma's config file (`plasmarc`) once persisted. Direct KWallet access is not possible from pure-QML applets on Plasma 6 (no QML API exists; tracked for a future C++ extension).
- All WebSocket requests (`get_states`, registries, `call_service`) are dispatched through per-request callbacks; concurrent registry refreshes can no longer overwrite each other's message ids.
- Device catalog titles now refresh immediately when a friendly name changes through `state_changed` events, and removed entities are dropped from the catalog right away.
- Default HA host is `homeassistant.local` instead of a hard-coded LAN IP.
- Port setting is stored as an integer (validated 1–65535) instead of a free-form string.
- Control-domain list is defined once in `ha_helpers.mjs` and reused by the manager.

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
