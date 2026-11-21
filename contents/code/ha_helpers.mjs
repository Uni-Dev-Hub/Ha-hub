import * as T from "../l10n/translations.mjs";
import * as MdiIcons from "./mdi_icons.mjs";

function cleanEntityId(id) {
    if (!id) return "";
    return id.toString().replace(/['"\[\]]/g, "").trim();
}

var CONTROL_DOMAINS = [
    "switch", "light", "climate", "fan", "cover", "lock", "outlet",
    "valve", "media_player", "vacuum", "lawn_mower", "water_heater",
    "humidifier", "siren", "camera", "alarm_control_panel", "input_boolean"
];

var ACTION_DOMAINS = ["scene", "script", "button", "automation", "input_button"];

var INFO_DOMAINS = ["sensor", "binary_sensor", "weather", "person", "update"];

var HELPER_DOMAINS = [
    "input_boolean", "input_number", "input_select", "input_text",
    "input_button", "number", "select", "text", "date", "time",
    "scene", "script", "automation", "button"
];

var IGNORED_DOMAINS = [
    "zone", "sun", "persistent_notification", "tts", "stt",
    "conversation", "assist_satellite", "wake_word"
];

function getDomain(entId) {
    if (!entId) return "";
    var parts = entId.toString().split(".");
    return parts.length > 1 ? parts[0] : "";
}

function isControlDomain(domain) {
    return CONTROL_DOMAINS.indexOf(domain) !== -1;
}

function isActionDomain(domain) {
    return ACTION_DOMAINS.indexOf(domain) !== -1;
}

function isInfoDomain(domain) {
    return INFO_DOMAINS.indexOf(domain) !== -1;
}

function isHelperDomain(domain) {
    return HELPER_DOMAINS.indexOf(domain) !== -1;
}

function isIgnoredDomain(domain) {
    return IGNORED_DOMAINS.indexOf(domain) !== -1;
}

function isSelectableEntity(entId) {
    var domain = getDomain(entId);
    if (!domain || isIgnoredDomain(domain)) return false;
    return isControlDomain(domain) || isActionDomain(domain) || isInfoDomain(domain) || isHelperDomain(domain);
}

function isSecondaryEntity(entId, regInfo) {
    if (!entId) return false;

    // Home Assistant's entity registry is the authoritative source. A registry
    // entry explicitly marked as config/diagnostic must never be treated as a
    // primary control.
    if (regInfo && regInfo.category) {
        return regInfo.category === "config" || regInfo.category === "diagnostic";
    }

    var domain = getDomain(entId);
    // Never hide controllable entities just because their object_id contains
    // words like "power" or "temperature". This was the reason valid switches
    // such as switch.power_switch disappeared from the list.
    if (isControlDomain(domain) || isActionDomain(domain)) return false;

    var lower = entId.toLowerCase();
    var name = lower.split(".").length > 1 ? lower.split(".")[1] : lower;
    var secondarySuffixes = [
        "battery", "battery_level", "voltage", "current", "power", "energy",
        "linkquality", "rssi", "lqi", "temperature", "humidity",
        "update_available", "signal_strength"
    ];
    for (var i = 0; i < secondarySuffixes.length; i++) {
        var kw = secondarySuffixes[i];
        if (name === kw || name.endsWith("_" + kw)) {
            return true;
        }
    }
    return false;
}

function getEntityRegistryInfo(entId, haManager) {
    if (!haManager || !entId || !haManager.entityRegistryMap) return null;
    return haManager.entityRegistryMap[entId] || null;
}

// Home Assistant computes `attributes.friendly_name` as the effective, fully
// qualified name of an entity ("Corridor Light"). The entity registry `name`
// field is only the *custom* name a user typed for that entity and usually
// drops the device prefix ("Light"), so the entity object always wins: that is
// the text the Home Assistant UI shows.
function getEntityFriendlyName(entId, entObj, regInfo) {
    if (entObj && entObj.attributes && entObj.attributes.friendly_name) {
        return entObj.attributes.friendly_name;
    }
    if (regInfo && regInfo.name) return regInfo.name;
    if (regInfo && regInfo.originalName) return regInfo.originalName;
    return entId || "";
}

// A name the user typed into the widget for one entity, kept as a JSON map
// `entity id -> name` in the configuration. It outranks everything Home
// Assistant offers, because it is the one name chosen on purpose: renaming in
// the widget settings is what the user reads at a glance in the popup.
function parseAliases(raw) {
    if (raw && typeof raw === "object") return Array.isArray(raw) ? {} : raw;
    if (typeof raw !== "string" || raw.trim().length === 0) return {};
    try {
        var map = JSON.parse(raw);
        return (map && typeof map === "object" && !Array.isArray(map)) ? map : {};
    } catch (error) {
        // A half-written or hand-edited value must not cost the user every
        // name they typed, and must not throw into a binding.
        return {};
    }
}

function aliasFor(aliases, entityId) {
    if (!aliases || !entityId) return "";
    var value = aliases[entityId];
    return (typeof value === "string" && value.trim().length > 0) ? value.trim() : "";
}

// The new map, with this entity's name set, or the entry dropped when the name
// is blank - which is how a rename is taken back. A blank name is never stored,
// so an empty string can never be shown as an entity's name.
function setAlias(aliases, entityId, name) {
    var source = parseAliases(aliases);
    var next = {};
    Object.keys(source).forEach(function (id) {
        var kept = aliasFor(source, id);
        if (kept) next[id] = kept;
    });
    if (entityId) {
        var value = (typeof name === "string") ? name.trim() : "";
        if (value) next[entityId] = value;
        else delete next[entityId];
    }
    return next;
}

// The alias of an entity as the manager sees it. Every caller that resolves a
// name already passes the manager, which is what lets one check here rename an
// entity everywhere: tiles, cards, the device list, the pickers.
function managerAlias(entityId, haManager) {
    if (!haManager || !entityId) return "";
    if (typeof haManager.entityAliasFor === "function") {
        var alias = haManager.entityAliasFor(entityId);
        return (typeof alias === "string") ? alias : "";
    }
    return aliasFor(parseAliases(haManager.entityAliases), entityId);
}

// What Home Assistant itself calls the entity - friendly name, registry name,
// device name - with no override in the way. The editor shows this under a
// name the user typed, so an override reads as one.
function entityTitleFromAssistant(entId, entObj, regInfo, haManager) {
    var name = getEntityFriendlyName(entId, entObj, regInfo);
    if (name && name !== entId) return name;

    var deviceId = regInfo && regInfo.deviceId
        ? regInfo.deviceId
        : (haManager && haManager.entityToDeviceMap ? haManager.entityToDeviceMap[entId] : "");
    var dev = haManager && deviceId && haManager.getDeviceRaw ? haManager.getDeviceRaw(deviceId) : null;
    if (dev) {
        return (dev.name_by_user || dev.name || name || entId);
    }
    return name || entId || "";
}

function getEntityTitle(entId, entObj, regInfo, haManager) {
    var alias = managerAlias(entId, haManager);
    if (alias) return alias;
    return entityTitleFromAssistant(entId, entObj, regInfo, haManager);
}

// The small line under an entity's name in the settings list: what Home
// Assistant calls it, then its id. One line for every row, whether or not the
// name was changed - a row that grew a second line only when renamed stood
// taller than its neighbours and left their controls off-centre. When Home
// Assistant has nothing to add, the id is the whole line.
function entityRowSubtitle(haName, entityId) {
    var id = entityId || "";
    var name = haName || "";
    if (!name || name === id) return id;
    return name + "  •  " + id;
}

function getDeviceDisplayName(dev, fallback) {
    if (!dev) return fallback || "";
    return dev.name_by_user || dev.name || fallback || dev.id || "";
}


function getLabelName(labelId, haManager) {
    if (!haManager || !labelId || !haManager._labelById) return labelId || "";
    var label = haManager._labelById[labelId];
    return label ? (label.name || label.label_id || labelId) : labelId;
}

function getLabelsText(labels, haManager) {
    if (!labels || labels.length === 0) return "";
    var names = [];
    for (var i = 0; i < labels.length; i++) {
        names.push(getLabelName(labels[i], haManager));
    }
    return names.join(", ");
}

function getDeviceTitle(entId, entObj, devId, haManager) {
    if (!entId) return "";
    if (haManager && devId) {
        var dev = haManager.getDeviceRaw ? haManager.getDeviceRaw(devId) : null;
        if (dev) return getDeviceDisplayName(dev, entId);
    }
    if (entObj && entObj.attributes) {
        if (entObj.attributes.friendly_name) return entObj.attributes.friendly_name;
    }
    return entId;
}

function getAreaName(cleanId, haManager) {
    if (!haManager || !cleanId) return "";
    var reg = haManager.entityRegistryMap ? haManager.entityRegistryMap[cleanId] : null;
    var devId = haManager.entityToDeviceMap ? (haManager.entityToDeviceMap[cleanId] || "") : "";
    var dev = (haManager.getDeviceRaw && devId) ? haManager.getDeviceRaw(devId) : null;
    var aId = (reg && reg.areaId)
        ? reg.areaId
        : ((haManager.entityToAreaMap && haManager.entityToAreaMap[cleanId]) || (dev && dev.area_id) || "");
    if (!aId) return "";
    if (haManager.getAreaRaw) {
        var area = haManager.getAreaRaw(aId);
        if (area && area.name) return area.name;
    }
    if (!haManager.areasList) return "";
    for (var i = 0; i < haManager.areasList.length; i++) {
        if (haManager.areasList[i].area_id === aId || haManager.areasList[i].id === aId) {
            return haManager.areasList[i].name || "";
        }
    }
    return "";
}

// The optional lang parameter (default "en") routes user-visible words
// through the HA-Hub translation catalogs.
function getBinarySensorStateTitle(state, deviceClass, lang) {
    var isOn = (state === "on");
    var dc = (deviceClass || "").toLowerCase();
    function w(off, on) { return T.translate(lang, isOn ? on : off); }
    if (dc === "door" || dc === "garage_door" || dc === "window" || dc === "opening") {
        return w("Closed", "Open");
    }
    if (dc === "lock") {
        return w("Locked", "Unlocked");
    }
    if (dc === "moisture") {
        return w("Dry", "Wet");
    }
    if (dc === "gas" || dc === "smoke" || dc === "carbon_monoxide") {
        return w("Clear", "Detected");
    }
    if (dc === "motion" || dc === "occupancy" || dc === "presence") {
        return w("Clear", "Detected");
    }
    if (dc === "problem" || dc === "safety" || dc === "tamper") {
        return w("OK", "Problem");
    }
    if (dc === "plug" || dc === "power" || dc === "connectivity") {
        return w("Disconnected", "Connected");
    }
    if (dc === "battery" || dc === "battery_charging") {
        return w("Normal", "Low");
    }
    if (dc === "sound" || dc === "vibration") {
        return w("Clear", "Detected");
    }
    if (dc === "running") {
        return w("Stopped", "Running");
    }
    if (dc === "update") {
        return w("Up to date", "Update available");
    }
    return w("Off", "On");
}

// Fallback icon when the entity/registry does not carry a custom icon.
// Names verified against the Breeze icon theme (with sane generic fallback).
var DOMAIN_ICONS = {
    "light": "brightness-high-symbolic",
    "switch": "media-flash-symbolic",
    "input_boolean": "media-flash-symbolic",
    "outlet": "media-flash-symbolic",
    "climate": "temperature-normal-symbolic",
    "water_heater": "temperature-warm-symbolic",
    "humidifier": "temperature-cold-symbolic",
    "fan": "view-refresh-symbolic",
    "cover": "window-symbolic",
    "lock": "object-locked-symbolic",
    "valve": "applications-system-symbolic",
    "media_player": "audio-speakers-symbolic",
    "vacuum": "applications-utilities-symbolic",
    "lawn_mower": "applications-utilities-symbolic",
    "siren": "dialog-warning",
    "camera": "camera-photo-symbolic",
    "alarm_control_panel": "new-audio-alarm-symbolic",
    "scene": "dialog-scripts-symbolic",
    "script": "dialog-scripts-symbolic",
    "automation": "dialog-scripts-symbolic",
    "button": "dialog-scripts-symbolic",
    "input_button": "dialog-scripts-symbolic",
    "sensor": "speedometer-symbolic",
    "binary_sensor": "network-wired-symbolic",
    "person": "user-identity-symbolic",
    "weather": "weather-clear-symbolic",
    "update": "system-software-update",
    "number": "speedometer-symbolic",
    "select": "view-list-details-symbolic",
    "text": "edit-none-symbolic",
    "input_number": "speedometer-symbolic",
    "input_select": "view-list-details-symbolic",
    "input_text": "edit-none-symbolic",
    "input_datetime": "preferences-system-time",
    "timer": "preferences-system-time",
    "date": "preferences-system-time",
    "time": "preferences-system-time"
};

function getDomainIcon(domain) {
    if (!domain) return "preferences-system-symbolic";
    return DOMAIN_ICONS[domain] || "preferences-system-symbolic";
}

// Where an entity's own icon should be drawn from. Home Assistant stores it as
// a Material Design Icons name ("mdi:ceiling-light"), which the Plasma icon
// theme cannot resolve, so those are drawn from the bundled MDI font by name;
// a plain icon theme name is passed through, and anything else - no icon, an
// icon set we do not ship (phu:, hass:), an MDI name the font lacks - falls
// back to the domain icon. Returns { kind: "mdi" | "theme", name }.
function resolveEntityIcon(rawIcon, domain) {
    var icon = rawIcon ? rawIcon.toString().trim() : "";
    if (icon.indexOf("mdi:") === 0) {
        var name = icon.substring(4).trim().toLowerCase();
        if (MdiIcons.mdiCodepoint(name)) return { kind: "mdi", name: name };
    } else if (icon.length > 0 && icon.indexOf(":") === -1) {
        return { kind: "theme", name: icon };
    }
    return { kind: "theme", name: getDomainIcon(domain) };
}

function getBinarySensorIcon(deviceClass, isOn) {
    var dc = (deviceClass || "").toLowerCase();
    if (dc === "door" || dc === "garage_door" || dc === "window" || dc === "opening") {
        return isOn ? "window-close-symbolic" : "window-symbolic";
    }
    if (dc === "moisture") {
        return "flavor-symbolic";
    }
    if (dc === "smoke" || dc === "gas" || dc === "carbon_monoxide") {
        return "dialog-warning";
    }
    if (dc === "motion" || dc === "occupancy" || dc === "presence") {
        return "user-identity-symbolic";
    }
    if (dc === "lock") {
        return isOn ? "object-unlocked-symbolic" : "object-locked-symbolic";
    }
    if (dc === "problem" || dc === "safety") {
        return "dialog-error-symbolic";
    }
    return isOn ? "radiomenu-active" : "radiomenu-inactive";
}

function getStatusDetailsText(cleanId, entObj, devId, haManager, lang) {
    function w(text) { return T.translate(lang, text); }
    if (!entObj || entObj.state === undefined || entObj.state === "unavailable" || entObj.state === "unknown") {
        return w("Unavailable");
    }
    var dom = cleanId ? cleanId.split(".")[0] : "";
    var state = entObj.state;
    var attrs = entObj.attributes || {};

    if (dom === "switch" || dom === "light" || dom === "outlet" || dom === "fan" || dom === "input_boolean") {
        return w(state === "on" ? "On" : "Off");
    }
    if (dom === "cover") {
        var pos = attrs.current_position;
        if (pos !== undefined) {
            return pos + "% • " + w(state === "open" ? "Open" : "Closed");
        }
        return w(state === "open" ? "Open" : "Closed");
    }
    if (dom === "lock") {
        return w(state === "locked" ? "Locked" : "Unlocked");
    }
    if (dom === "climate") {
        var curT = attrs.current_temperature;
        var hvac = attrs.hvac_action || state;
        return (curT !== undefined ? curT + "°C • " : "") + w(hvac);
    }
    if (dom === "binary_sensor") {
        return getBinarySensorStateTitle(state, attrs.device_class, lang);
    }
    if (dom === "vacuum") {
        if (state === "cleaning") return w("Cleaning");
        if (state === "docked") return w("Docked");
        if (state === "returning") return w("Returning");
        if (state === "paused") return w("Paused");
        if (state === "error") return w("Error");
        return state;
    }
    if (dom === "media_player") {
        if (state === "playing") return w("Playing");
        if (state === "paused") return w("Paused");
        if (state === "idle") return w("Idle");
        if (state === "off") return w("Off");
        return state;
    }
    if (dom === "person") {
        return w(state === "home" ? "Home" : "Away");
    }
    if (dom === "sensor") {
        var u = attrs.unit_of_measurement ? " " + attrs.unit_of_measurement : "";
        return state + u;
    }
    if (dom === "alarm_control_panel") {
        if (state === "disarmed") return w("Disarmed");
        if (state === "armed_home") return w("Armed Home");
        if (state === "armed_away") return w("Armed Away");
        if (state === "armed_night") return w("Armed Night");
        if (state === "triggered") return w("Triggered");
        return state;
    }
    if (dom === "valve") {
        return w(state === "open" ? "Open" : "Closed");
    }
    if (dom === "lawn_mower") {
        if (state === "mowing") return w("Mowing");
        if (state === "docked") return w("Docked");
        if (state === "paused") return w("Paused");
        if (state === "error") return w("Error");
        return state;
    }
    if (dom === "siren") {
        return w(state === "on" ? "On" : "Off");
    }

    var unit = attrs.unit_of_measurement ? " " + attrs.unit_of_measurement : "";
    return state + unit;
}

// One-line value for the popup header: "23.5 °C", optionally prefixed with the
// entity name ("Гостиная: 23.5 °C"). Used by the header and its settings
// preview so both always show the same text.
function getEntityHeaderValue(entId, entObj, haManager, lang, withName) {
    var cleanId = cleanEntityId(entId);
    if (!cleanId || !entObj) return "";
    var value = getStatusDetailsText(cleanId, entObj, null, haManager, lang);
    if (!withName) return value || "";
    var entry = haManager && haManager.getCatalogEntry ? haManager.getCatalogEntry(cleanId) : null;
    var name = entry && entry.name ? entry.name : "";
    return name ? (name + ": " + value) : (value || "");
}

// The tray icon is stored as a mode plus an icon name or an image path, so the
// plasmoid can offer "follow the connection state", "an icon from the theme"
// or "my own picture". Returns { name, path }; exactly one of them is set.
function resolveIconChoice(mode, iconName, iconPath, onlineName, offlineName, connected) {
    if (mode === "theme" && iconName) return { name: iconName, path: "" };
    if (mode === "custom" && iconPath) return { name: "", path: iconPath };
    return { name: connected ? (onlineName || "") : (offlineName || ""), path: "" };
}

// Icons offered in the tray icon gallery. Every name was checked against the
// Breeze theme that ships with Plasma 6.
var TRAY_ICON_CHOICES = [
    "home",
    "network-server",
    "network-server-symbolic",
    "network-wireless",
    "network-workgroup",
    "internet-services",
    "computer",
    "applications-system",
    "preferences-system",
    "preferences-desktop-color",
    "preferences-desktop-display",
    "preferences-desktop-theme-global",
    "view-grid-symbolic",
    "configure",
    "security-high",
    "security-low",
    "object-locked",
    "object-unlocked",
    "dialog-warning",
    "dialog-information",
    "system-run",
    "utilities-system-monitor",
    "weather-clear",
    "weather-clear-night",
    "weather-few-clouds",
    "weather-overcast",
    "weather-showers-day",
    "weather-snow",
    "weather-fog",
    "weather-storm",
    "thermometer",
    "thermometer-1-celsius",
    "clock",
    "view-calendar",
    "player-volume",
    "media-playback-start",
    "applications-multimedia",
    "headphones",
    "tv",
    "phone",
    "printer",
    "camera-web",
    "scanner",
    "applications-games",
    "tag",
    "bookmarks",
    "system-search",
    "user-identity"
];

function formatTimeInState(lastChanged) {
    if (!lastChanged) return "";
    var changedDate = new Date(lastChanged);
    var now = new Date();
    var diffMs = now.getTime() - changedDate.getTime();
    if (isNaN(diffMs) || diffMs < 0) return "";

    var diffSec = Math.floor(diffMs / 1000);
    var diffMin = Math.floor(diffSec / 60);
    var diffHour = Math.floor(diffMin / 60);
    var diffDay = Math.floor(diffHour / 24);

    if (diffDay > 0) return diffDay + "d";
    if (diffHour > 0) return diffHour + "h";
    if (diffMin > 0) return diffMin + "m";
    return diffSec + "s";
}

function formatLastChangedDate(lastChanged, fallback, lang) {
    if (!lastChanged) return fallback || "—";
    var d = new Date(lastChanged);
    if (isNaN(d.getTime())) return fallback || "—";
    var hours = String(d.getHours()).padStart(2, "0");
    var mins = String(d.getMinutes()).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var month = T.translate(lang, monthNames[d.getMonth()]);
    return hours + ":" + mins + ", " + day + " " + month;
}

export {
    aliasFor,
    cleanEntityId,
    formatLastChangedDate,
    formatTimeInState,
    getAreaName,
    getBinarySensorIcon,
    getDomainIcon,
    getBinarySensorStateTitle,
    getDeviceDisplayName,
    getDeviceTitle,
    getDomain,
    getEntityFriendlyName,
    getEntityHeaderValue,
    getEntityRegistryInfo,
    entityRowSubtitle,
    entityTitleFromAssistant,
    getEntityTitle,
    getLabelName,
    getLabelsText,
    getStatusDetailsText,
    isActionDomain,
    isControlDomain,
    isHelperDomain,
    isIgnoredDomain,
    isInfoDomain,
    isSecondaryEntity,
    isSelectableEntity,
    managerAlias,
    parseAliases,
    resolveEntityIcon,
    resolveIconChoice,
    setAlias,
    TRAY_ICON_CHOICES,
    CONTROL_DOMAINS,
    ACTION_DOMAINS,
    INFO_DOMAINS,
    HELPER_DOMAINS,
    IGNORED_DOMAINS,
};
