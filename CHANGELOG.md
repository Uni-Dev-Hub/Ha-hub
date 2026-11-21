# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.3.0] - 2026-11-21

### Added
- 21 more languages, all of them complete: Belarusian, Polish, Czech, Slovak,
  Bulgarian, Slovenian, Serbian in both scripts, Bosnian, Danish, Norwegian in
  both written standards, Dutch, Swedish, Icelandic, Italian, Portuguese,
  Brazilian Portuguese, Finnish, Estonian and Lithuanian — 30 in all. Completeness
  is not a promise but a test: every catalog is read against every string the
  widget can ask for, in both directions, so a language cannot ship half-done and
  a string cannot exist in one language only.
- A language is a file of its own, `contents/l10n/catalogs/<code>.js`, and
  `scripts/new-catalog.mjs` registers a new one — code, name, strings — refusing
  to add one that is incomplete or that a test cannot load.
- Serbian and Bosnian are separate catalogs, not one file with two flags: Bosnian
  writes ijekavian forms where Serbian does not, and the pairs that say so are
  written down rather than guessed at. The same for Norwegian bokmål and nynorsk,
  and for Portuguese and Brazilian Portuguese, which differ in words — umidade and
  humidade, arquivo and ficheiro, "Conectando…" and "A ligar…" — not only spelling.

### Fixed
- The widget followed the saved language again. The settings dialog was
  translated while the popup beside it stayed in the system language: the bridge
  that hands the language to an engine called into the catalog module through a
  *folder* import, which brings in the singleton and not the module, so every call
  threw a ReferenceError — logged once, then swallowed, because a property binding
  that fails simply stops existing. Every configured language resolved to "no
  catalog", which is the system language. `import "../../l10n"` and
  `import "../../l10n/translations.mjs" as L10N` differ by the part of the line
  above the code that breaks, so a test now reads every file that mentions `L10N`
  and demands the import that defines it, and the QML test asks the bridge itself
  what language it settled on.
- A language saved as a full tag finds its catalog. `zh-Hans-CN` and `pt-BR`
  answer zh and pt_BR, `sr-Latn` answers the Latin Serbian catalog, and a saved
  `zh` stays zh instead of being dropped for not naming a region — which had been
  silently turning a chosen language back into English.
- The names of the sections down the side of the settings dialog are in the
  configured language. That list is built by the dialog's engine before any page
  of it exists, so it had nothing to read the language from; it has its own bridge
  now.
- `Labels:` in German was still English. A scan for catalog values identical to
  their English key leaves only words that are the same in both languages.

## [1.2.9] - 2026-11-21

### Fixed
- The fields of a settings page stand on the left again. Kirigami gives a form
  the whole width of the space it is put in and centres the label and field
  columns of its content inside that width, so a form as wide as the window
  showed them somewhere near its middle, with the leftovers of that width on
  both sides. Each form is now put in a box as wide as the form asks itself to
  be, and the box stands on the left; in a window narrower than the form, the
  box follows it down and the form reflows into one column.
- The tile list is a table again. The three dropdowns of a row — size, content,
  group — started at a different place in every row: the block with the entity's
  name measured itself to its own text, so a short name moved them left, and a
  row whose name had been changed carried the reset button the other rows did
  not have, which took width from the fields that fill a row. The name block now
  asks for a width by number, and the place of the reset button is kept on every
  row. Test laid out in the hosted dialog: the three columns of the list start
  at the same x in all rows, at 460, 620, 900 and 1380 px.

## [1.2.8] - 2026-11-21

### Fixed
- The settings pages fit the window. Kirigami makes a form as wide as the
  widest thing in it, and a hint line that could wrap was asking for the width
  of its whole text in one line: the form took that width, and the fields,
  their labels and the hints themselves ran past the right edge and were cut
  off — while the window could not be dragged narrower than that phantom width.
  Everything a form had no other measure by is now bounded by the width the
  page offers, so a field fills the window without leaving it, the hints wrap,
  and the dialog goes down to a narrow window. A regression test lays every
  page out in the widest language at five widths and asks that nothing reach
  past the edge.
- Rows of the tile list are one height. A renamed entity grew a second line
  under its name, which made that row taller than its neighbours and left its
  three dropdowns off-centre. The line under a name is now one line on every
  row — what Home Assistant calls the entity, and its id — and the reset button
  is what marks a row whose name was changed.
- A page heading is in the language of the widget. Plasma hands a settings page
  a heading of its own when it opens it, taken from the category name as it was
  read *before* the page had set the language, and the assignment breaks the
  page's own binding — so the first page opened kept the language of the system
  in its heading («Allgemein» next to a Russian dialog), while the pages opened
  after it were correct. Each page now puts its own heading back.
- The two device-list checkboxes on the General page are no longer both headed
  «Device list:». Only the first carries the heading now, and the second sits
  under it in the column of fields.

## [1.2.7] - 2026-11-21

### Added
- Entities can be renamed. In **Settings → Dashboard**, click an entity's name
  in the tile list: it turns into a field, and what you type becomes the name
  the widget shows — on the tile, in the device list and in the cards. The name
  Home Assistant gives the entity stays visible underneath, and the row gets a
  reset button that takes the name back. The rename belongs to the entity, not
  to one tile, so the same name appears wherever that entity is shown, and it
  survives removing the tile or the group.
- Names are saved with the rest of the configuration, so they are still there
  after Apply, after closing the settings, and after a restart of Plasma.

## [1.2.6] - 2026-11-21

### Added
- The dashboard font is a setting. **Settings → Dashboard** now has a **Font**
  picker, listing every font that is installed, and a **Font size** picker.
  Both apply to the tile text — the name and the value — and the preview on
  that page shows the result before Apply. The row height follows the chosen
  size, so bigger type is printed whole instead of being cut to an ellipsis.
- The grid columns picker offers 5 alongside 2, 3, 4 and 6, and a count saved
  outside the list is shown instead of the picker quietly displaying another.

### Fixed
- The tray icon picker landed over the settings dialog's header, half outside
  it, and dimmed a dialog that was already modal. It was a `Popup` anchored to
  `Overlay.overlay` from its own scope. It is a `Kirigami.Dialog` now, the same
  thing Plasma's own configuration dialog uses, so it places itself correctly
  and closes on Escape or a click outside.
- A chosen language could be erased a few seconds after Apply. Two things
  conspired. The picker wrote the language into the applet's own configuration,
  behind the settings dialog's back - the dialog holds a copy of the
  configuration of its own, still holding the old language, and wrote that back
  over the choice when it closed. And the page declared its fallback for the
  language as `"system"`, which is exactly what Apply writes out for the page it
  is showing. A pick now changes `cfg_language` and nothing else, the fallback is
  the language the dialog is showing, and Apply is the single writer. The widget
  still switches language at once: the bridge watches the configuration Apply
  writes to, and the journal says `HA-hub: language -> xx`.

## [1.2.5] - 2026-11-21

### Fixed
- Picking a language in Settings did nothing when clicked. The list's delegate
  wrote to `popup.closed`, which is read-only, so every click died on a
  TypeError before the language was handed over - the only thing that still
  worked was the language flipping under the mouse as the list was hovered,
  which is what made the setting look like it changed and then refused to stay.
  A click now applies the language, closes the list and updates the button.
- The widget never saw the saved language at all, whatever was written to the
  file. `LanguageBridge` lives in a file of its own, and a component is created
  in the context of the file that defines it, while Plasma keeps `Plasmoid` in a
  context of its own for the applet: the bridge was reading a configuration it
  could not see. The applet now hands the configuration to it, and the bridge
  re-reads it every time the popup opens. Startup says what it found in the
  journal: `journalctl --user | grep HA-hub`.
- The dialog opens in the configured language instead of the system one, and the
  picker no longer rebuilds its list under a pick.

### Notes
- The language applies the moment it is picked and is stored on Apply, like
  every other setting - a settings page cannot store it by itself, for the same
  context reason as above. A hint under the picker says so, and Plasma keeps
  warning about unsaved changes if the dialog is closed first.

### Added
- 5 columns in Settings → Dashboard → Grid columns. The grid has always packed
  any column count - the preview on that page uses five - only the picker never
  offered it. A saved count outside the offered list is now added to it, so the
  control cannot show one number while the configuration holds another.

### Tests
- The language picker is now driven through the real controls: a click on a
  row, then the keyboard path. The version that shipped broken passed its test,
  because that test called the page's function and skipped the broken delegate.
- Guards for controls that write to read-only properties, for signal handlers
  that rely on injected parameters, and for the list of column counts.

## [1.2.4] - 2026-11-21

### Fixed
- The language chosen in Settings no longer jumps back to the system language
  when the dialog is closed. It used to be stored only in the page's `cfg_`
  property and handed to the configuration when Apply was pressed - and Plasma
  copies those page by page, so a re-created or inactive page handed back its
  declared `system` default. KConfig treats a default value as "not set" and
  drops the entry from the file, which wiped the saved language. The picker now
  writes the language through the configuration itself, so the choice is stored
  the moment it is made - the same moment it becomes visible.
- The language list no longer rebuilds itself while the picker is used: the
  model holds only codes and the names each language writes about itself, and
  the "System language" row is translated where it is displayed. A translated
  string in the model made the control reset its selection exactly when the
  interface switched language.

## [1.2.3] - 2026-11-21

### Changed
- A tile row is now two zones, and the device name finally has room: the glyph
  and the state answer (mini switch, value, pictogram) share the top, the name
  runs across the whole width of the tile along the bottom. In one line the name
  of a one-column tile used to get ~35 px after the glyph and the switch, which
  is why "Большая люстра" printed as "Бол шо…".
- The glyph shrank with it (20 px to the small icon size, 16 px), since the name
  is what a row is read by. Icon-only tiles keep the big glyph, centred.
- The row grew slightly to hold both zones (2.6 to 3.1 grid units), so two lines
  of the name fit under the glyph.

## [1.2.2] - 2026-11-21

### Fixed
- The language chosen in Settings → General finally changes the interface. The
  translation singleton used to read the language out of the widget
  configuration itself, but a QML singleton is created outside the context
  where Plasma exposes that configuration, so the read silently returned
  nothing and every screen - popup, panel tooltip, settings dialog - stayed on
  the system language however the picker was set. An object that does see the
  configuration now hands the value over, so a saved choice is applied
  everywhere, and the settings dialog retranslates the moment a language is
  picked, without waiting for Apply.

### Changed
- Tile type is lighter and lower: the name is 7.5 pt without bold weight and
  sits at the bottom edge of the row, under the glyph, so a long name labels
  the row instead of floating in the middle of it. The value at the right edge
  matches the same size and weight.

## [1.2.1] - 2026-11-21

### Changed
- Tile names are smaller (8 pt) and may break over two lines, so a long device
  name stays readable without making the row any taller.
- Tiles now show the icon the entity has in Home Assistant. HA stores icons as
  Material Design Icons names ("mdi:ceiling-light"), which no icon theme can
  resolve, so the widget ships that font and draws the very glyph HA shows -
  a ceiling light, a floor lamp and a motion sensor finally look different.
  Entities without an icon, and icon sets we do not ship, keep the Plasma
  domain icon.
- The mini switch is drawn smaller: at full size it took a third of a
  one-column row away from the name.

### Added
- `scripts/update-mdi-icons.mjs` regenerates the MDI name table
  (`contents/code/mdi_icons.mjs`) when the bundled font is updated.

## [1.2.0] - 2026-11-21

### Changed
- Dashboard tiles abandoned the square: every tile is one compact row now
  (height fixed, width one/two/all columns), so the dashboard shows many more
  devices at the same height. The removed "large" size migrates to "full
  width" automatically - no configuration touches needed.
- The row says everything in one line: entity icon and name on the left, and
  on the right the shortest honest answer - a mini switch for lights and
  switches, a value for sensors and climate ("-3.5 °C", "54 %", "45%"), a
  pictogram for locks, covers, motion sensors and media. No more status
  sentences; the full name and state text moved into the tooltip.
- Available tile sizes in the settings are now "1 column / 2 columns / Full
  width", matching the new row grid.

## [1.1.2] - 2026-11-21

### Changed
- Dashboard tiles adopted the device-card concept: an icon plus the entity
  name on top, a state line with an on/off dot at the bottom - on every tile,
  including the small 1x1 ones, which used to hide all text and turned the
  dashboard into a wall of identical icons. A tooltip hands back the full
  name when it has to be elided.
- Tiles got more informative and more alive: lights that are on report their
  brightness ("On • 80%"), hover brightens a tile like in the device list.
  In icon-only mode the big glyph stays, now with the state line below it.

### Fixed
- Header avatar: the circular "mask" was a solid rectangle painted over the
  loaded picture, so the user photo was never visible. The header now uses
  Kirigami.Avatar, which shows the photo properly - or the user's initials
  when the Home Assistant account has no avatar set.

## [1.1.1] - 2026-11-20

Focus of this release: the dashboard tiles grew up. The feature set is exactly
as before - the look was rebuilt to be calm, compact and informative.

### Changed
- Dashboard tiles are now quiet themed cards in the same visual family as the
  device cards (themed surface, hairline border, soft radius) instead of full
  colour blocks. On light Plasma themes the dashboard no longer screams.
- Colour means state: an active entity tints its icon, state line and title
  with the group accent; inactive entities stay neutral grey, unavailable
  ones dim back. The group colour setting (now labelled "Accent color")
  tunes this accent and is auto-adjusted to stay readable in light and dark
  themes without losing its hue.
- Tile content restructured for a glance: the entity name leads at the top,
  the current state ("22.5 °C • Heating", "45% • Open", "Home", "-3.5 °C")
  is the central, boldest line, the icon supports it. Tighter margins and a
  smaller icon fit more information per tile, groups sit closer together.

## [1.1.0] - 2026-11-19

Focus of this release: dashboard tile groups in the Metro style, entity names
exactly as Home Assistant shows them, a new "Appearance" settings page (header
avatar and entity, tray icon, which views are shown) and settings pickers that
fit into the popup.

### Added
- New "Appearance" settings page: choose which views the popup shows (Dashboard
  and/or Devices), which Home Assistant person provides the header picture,
  which entity value is displayed next to the greeting (with a live preview),
  and which icon the panel shows.
  With only one view enabled the switch button between them is hidden and the
  popup opens that view directly.
- Header: round user picture from Home Assistant (the `entity_picture` of the
  selected person) and a configurable entity value, e.g. `-3.5 °C`. The picture
  falls back to the identity icon when the person has none or it cannot be
  loaded.
- Tray/panel icon is now selectable: a gallery of Breeze icons or an own image
  file, with the old automatic connection-status behaviour as default. Offline
  still dims the icon.
- Metro-style dashboard: tiles grouped under their own heading, each group
  filled with one selectable colour (20-swatch palette or any `#rrggbb`), the
  text colour adapting for contrast. Tiles come in four sizes and can show the
  entity name, its icon or both — per tile or as a dashboard-wide default.
  Tapping a tile switches the entity directly (lights, switches, fans, locks,
  scripts, scenes…), a long press opens its details.

### Changed
- The dashboard card grid was replaced by the Metro tile groups. Cards saved
  in 1.0 migrate automatically into one untitled group that keeps following
  the system accent colour (1x1 → small, 2x1 → wide, 1x2 → medium, 2x2 →
  large).
- Entity titles are exactly the entity's friendly name — the text Home
  Assistant itself shows. The previous "Device • Channel" suffix for
  same-named channels of one device was removed on request; the dashboard
  entity filter now lists every domain that exists in Home Assistant (it used
  to drop a domain once all of its entities were already placed).
- The header no longer shows the version badge; the user picture from Home
  Assistant and a configurable entity (e.g. a temperature sensor) are shown
  there instead.
- Entity pickers in settings filter entity types through a drop-down list with
  counts; the row of buttons did not fit into the settings dialog.
- Settings pages are ordered: General, Dashboard, Favorite Devices,
  Appearance.

### Fixed
- Dashboard rendering and responsiveness rebuilt end to end:
  - tiles are placed by a pure packing function with explicit coordinates
    instead of a layout manager — the old grid fed the tiles' preferred widths
    back into the unit width, so tiles grew unbounded or vanished behind the
    clip area and taps hit the wrong geometry;
  - every tile title, status and icon is now precomputed once per debounced
    burst of Home Assistant state changes (and once per settings or language
    change), so state storms no longer re-resolve every tile on every message;
  - the settings pages (Dashboard, Favorite Devices, Appearance) open their
    Home Assistant connection only when first shown instead of keeping three
    extra WebSocket clients and entity catalogues alive.
- Language chosen in settings now actually switches the whole interface
  instantly: the translation facade now listens to the configuration change
  signal instead of relying on the kcfg property notification.
- "Appearance" settings page: labels and fields no longer overlap each other
  (cells that Kirigami.FormLayout measured as zero height).
- Error output of the dashboard settings page (`containsMouse is not defined`
  on the group colour chip) is gone.

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
