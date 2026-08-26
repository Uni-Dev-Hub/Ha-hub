# HA-Hub — Home Assistant Widget for KDE Plasma 6

Native, lightweight, and responsive Home Assistant monitoring and control widget for KDE Plasma 6.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-blue?logo=kde)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Version](https://img.shields.io/badge/Version-1.0.0--beta1-orange)

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
  <img width="280" alt="HA-Hub Settings About" src="https://github.com/user-attachments/assets/2737a38b-68a4-4ec0-8fe6-bb309cd1b4ce" />
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
- **Native Look & Feel:** Seamless integration with your KDE color scheme and font settings using Kirigami and PlasmaComponents 3.0.
- **Internationalization (i18n):** Clean base English interface ready for community translations.

---

## Installation

### Manual Installation (.plasmoid)

1. Download the latest `org.kde.plasma.hahub-1.0.0-beta1.plasmoid` from the [Releases](https://github.com/Uni-Dev-Hub/Ha-hub/releases) section.
2. Install via terminal:
   
   kpackagetool6 --type Plasma/Applet --install org.kde.plasma.hahub-1.0.0-beta1.plasmoid
   
3. To update an existing installation:

   kpackagetool6 --type Plasma/Applet --upgrade org.kde.plasma.hahub-1.0.0-beta1.plasmoid



## Configuration

1. Add **HA-Hub** to your Plasma panel or desktop.
2. In the setup wizard, select your discovered Home Assistant instance or enter your host IP (e.g., `homeassistant.local` or `192.168.1.100`) and port (default `8123`).
3. Generate a **Long-Lived Access Token** in your Home Assistant user profile (`/profile/security`) and paste it into the widget settings.
4. Pin your favorite devices in the **Favorite Devices** settings tab.

---

## Feedback & Community

The **Dashboard** tab is currently in active concept development. We welcome your feedback, feature requests, and ideas:
- Open an issue or join discussions on [GitHub](https://github.com/Uni-Dev-Hub/Ha-hub).
- Contact: `unidevhub@gmail.com`

---

## License

This project is licensed under the [GNU General Public License v3.0 or later](LICENSE).
