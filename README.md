# HA-Hub Revived — Home Assistant widget for KDE Plasma 6

A maintained fork of [HA-Hub](https://github.com/Uni-Dev-Hub/HA-hub) by **Oleksandr Afanasiev**:
control and monitor Home Assistant from your Plasma desktop or panel.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-blue?logo=kde)
![License](https://img.shields.io/badge/License-GPL--3.0--or--later-green)
![Version](https://img.shields.io/badge/Version-2.0.1-orange)

> **A note from the maintainer.** I really liked the idea behind HA-Hub, so I decided to improve
> it for my own needs. I have no intention whatsoever of taking credit for the original
> developer's work: this fork only aims to build on it and make it better. All the merit for
> the idea and the foundations belongs to Oleksandr Afanasiev.
>
> The original project has had no activity since its first release, so the improvements live
> here, under the same GPL-3.0 license. If upstream becomes active again, I'll gladly offer
> these changes back.

---

## What's new in 2.0

**Connection**
- Fixed: after the first dropped connection the widget never reconnected (a stale
  "manual disconnect" flag swallowed the close event).
- Exponential back-off reconnect (3 s → 60 s) and a ping watchdog that detects dead sockets
  after suspend or network changes (useful behind reverse proxies such as Cloudflare).
- The device list stays visible (dimmed) while reconnecting.

**Interface**
- Three views: **Rows**, **Tiles** and **Liquid Glass cards**, selectable from the header.
- Column count adapts to the widget width; the widget can be resized freely and made small.
- Rounded corners (0–32 px) and background opacity, configurable, on the desktop.
- Colors are derived entirely from the Plasma color scheme and follow theme changes live.
- 49 bundled monochrome icons, so every entity type has an icon regardless of the icon theme.
- Category tabs (Favorites, Lights, Sensors, More, All), search across all entities,
  room filter, remembered tab.
- Quick actions: click an entity icon to toggle it; buttons for covers, locks and media.
- Diagnostic, configuration and hidden entities are filtered out of the lists; each entity
  shows its own name instead of the shared device name.

**Performance**
- Lists are rebuilt only when the set of entities changes, not on every state update.
- O(1) device lookups (relevant with hundreds of entities).

**Translations**
- English source strings; Italian translation included. New languages are welcome
  (see below).

---

## Installation

### From the KDE Store
*Get New Widgets…* → search for **HA-Hub Revived**.

### Manual
```bash
kpackagetool6 --type Plasma/Applet --install io.github.thepierlux.hahubrevived-2.0.1.plasmoid
# update:
kpackagetool6 --type Plasma/Applet --upgrade io.github.thepierlux.hahubrevived-2.0.1.plasmoid
```

### From source
```bash
git clone https://github.com/ThePierlux/ha-hub-revived
cd ha-hub-revived
translate/build.sh               # compile translations
kpackagetool6 --type Plasma/Applet --install .
```

## Setup
1. Add the widget, open its settings.
2. Enter your Home Assistant host, port and whether to use SSL (`wss://`).
3. Create a **long-lived access token** in Home Assistant (Profile → Security) and paste it.

The token is stored in your local Plasma configuration only.

## Translating
1. Copy `translate/template.pot` to `translate/<lang>.po` and translate it.
2. Run `translate/build.sh` to compile it into the package.
3. Open a pull request.

Run `translate/build.sh --package` to build the `.plasmoid` archive.

---

## Credits

- **Original author:** Oleksandr Afanasiev — [Uni-Dev-Hub/HA-hub](https://github.com/Uni-Dev-Hub/HA-hub).
  The architecture, the Home Assistant WebSocket client, the device detail pages and the
  favorites manager come from the original project. Its full history is preserved in this
  repository.
- **Fork maintainer:** [ThePierlux](https://github.com/ThePierlux).
- **AI-assisted development:** the 2.0 rework (connection fixes, new views, icons,
  performance work, translations) was written with **Claude** (Anthropic, Claude Opus 5.5
  via Claude Code), after an earlier exploratory pass in Google Antigravity, and reviewed
  and tested by the maintainer on a real Home Assistant setup.

## Contributors

| | Role |
|---|---|
| [Oleksandr Afanasiev](https://github.com/Uni-Dev-Hub) | Original author of HA-Hub |
| [ThePierlux](https://github.com/ThePierlux) | Fork maintainer, design direction, testing |
| Claude (Anthropic) | Code for the 2.0 rework, via [Claude Code](https://claude.com/claude-code) |

Contributions and translations are welcome.

## License

GPL-3.0-or-later, same as the original project. See [LICENSE](LICENSE).
