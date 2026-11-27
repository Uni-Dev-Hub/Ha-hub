# HA-Hub — Home Assistant Widget for KDE Plasma 6

Native, lightweight, and responsive Home Assistant monitoring and control widget for KDE Plasma 6.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-blue?logo=kde)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Version](https://img.shields.io/badge/Version-1.1.0--beta1-orange)

> [!NOTE]
> **Community Notice:** This project is currently in active beta testing — your feedback, bug reports, and feature suggestions are very welcome!  
> Please also note that development is based in Ukraine, so updates and responses may occasionally be delayed due to power outages caused by ongoing Russian aggression. Thank you for your patience and support.

---

### Screenshots

<p align="center">
  <img width="210" alt="HA-Hub Popup View" src="https://github.com/user-attachments/assets/23826770-ce20-466e-ad63-0421a8927f5c" />
  <img width="210" alt="HA-Hub Device Details" src="https://github.com/user-attachments/assets/9a61e33b-2241-4a1c-8127-e6b2213882fc" />
  <img width="210" alt="HA-Hub Thermostat Control" src="https://github.com/user-attachments/assets/2b872fd8-5e2b-4cdc-8a7e-48aa68bf5d57" />
  <img width="210" alt="HA-Hub Light Controls" src="https://github.com/user-attachments/assets/2418c94e-3440-4aab-ad3e-f041aa71320b" />
</p>

<p align="center">
  <img width="280" alt="HA-Hub Settings General" src="https://github.com/user-attachments/assets/ffc361a8-d30f-4d45-a466-ae91b26eac96" />
  <img width="280" alt="HA-Hub Settings Favorites" src="https://github.com/user-attachments/assets/c8aad2e4-d256-4ff5-84a3-ea3b89caad83" />
</p>

---

## Features

- **Real-Time WebSocket Sync:** Direct connection to Home Assistant WebSocket API with instantaneous two-way state updates and auto-reconnect.
- **Local Network Auto-Discovery:** Automatically scans and detects Home Assistant instances on your LAN.
- **Support for 15+ Device Domains:**
  - **Lights:** Brightness adjustment, HSV color picker, Kelvin color temperature, and lighting effects.
  - **Climate & Thermostats:** Target temperature, HVAC operating modes (Heat, Cool, Auto), fan and swing presets.
  - **Power Plugs & Energy Monitoring:** Real-time wattage/current/voltage load, daily/monthly totals, and interactive 7-day consumption chart.
  - **Security & Access:** Smart locks, alarm control panels, camera snapshot feeds, and alarm sirens.
  - **Covers & Blinds:** Position slider and Open / Stop / Close controls.
  - **Appliances:** Robot vacuums and robotic lawn mowers (Clean, Pause, Return to Dock, Locate).
  - **Media Players:** Track info, volume control, mute, and playback transport buttons.
  - **Valves & Water Heaters:** Shutoff valves (water/gas) and boiler temperature settings.
  - **Presence & Sensors:** Person location tracking (with OpenStreetMap links) and binary sensors.
- **Favorite Devices Manager:** Simple search, filtering, and custom ordering for your pinned devices.
- **Three views:** compact rows, tiles and Liquid Glass cards, with adjustable corner radius and background opacity.
- **Native Look & Feel:** Seamless integration with your KDE color scheme and font settings using Kirigami and PlasmaComponents 3.0.
- **Internationalization (i18n):** Clean base English interface ready for community translations (Italian included).

---

## What's New in 1.1

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

### Manual Installation (.plasmoid)

1. Download the latest `org.kde.plasma.hahub-1.1.0-beta1.plasmoid` from the [Releases](https://github.com/Uni-Dev-Hub/Ha-hub/releases) section.
2. Install via terminal:
   
   ```bash
   kpackagetool6 --type Plasma/Applet --install org.kde.plasma.hahub-1.1.0-beta1.plasmoid
   ```
3. To update an existing installation:

   ```bash
   kpackagetool6 --type Plasma/Applet --upgrade org.kde.plasma.hahub-1.1.0-beta1.plasmoid
   ```

### From Source

```bash
git clone https://github.com/Uni-Dev-Hub/Ha-hub
cd Ha-hub
translate/build.sh    # compile translations
kpackagetool6 --type Plasma/Applet --install .
```

Run `translate/build.sh --package` to build the `.plasmoid` archive.

## Configuration

1. Add **HA-Hub** to your Plasma panel or desktop.
2. In the setup wizard, select your discovered Home Assistant instance or enter your host IP (e.g., `homeassistant.local` or `192.168.1.100`) and port (default `8123`).
3. Generate a **Long-Lived Access Token** in your Home Assistant user profile (`/profile/security`) and paste it into the widget settings.
4. Pin your favorite devices in the **Favorite Devices** settings tab.

---

## Translating

1. Copy `translate/template.pot` to `translate/<lang>.po` and translate it.
2. Run `translate/build.sh` to compile it into the package.
3. Open a pull request.

---

## Feedback & Community

HA-Hub is in beta and actively looking for feedback. We welcome your bug reports, feature requests, and ideas:
- Open an issue or join discussions on [GitHub](https://github.com/Uni-Dev-Hub/Ha-hub).
- Contact: `unidevhub@gmail.com`

---

## Contributors

| | Role |
|---|---|
| [Oleksandr Afanasiev](https://github.com/Uni-Dev-Hub) | Author and maintainer |
| [ThePierlux](https://github.com/ThePierlux) | 1.1 improvements: views, connection fixes, translations, testing |
| Claude (Anthropic) | Code for the 1.1 improvements, via [Claude Code](https://claude.com/claude-code) |

Contributions are welcome: open an issue or a pull request.

---

## License

This project is licensed under the [GNU General Public License v3.0 or later](LICENSE).
