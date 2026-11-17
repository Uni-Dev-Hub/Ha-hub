// Translation helper: i18n() is provided by Plasma's QML context; fall back to the
// English source when unavailable. Extra args replace %1, %2, ...
function tr(text) {
    var args = Array.prototype.slice.call(arguments, 1);
    if (typeof i18n === "function") return i18n.apply(null, [text].concat(args));
    return text.replace(/%(\d+)/g, function(m, n) { var v = args[n - 1]; return v === undefined ? m : v; });
}

function cleanEntityId(id) {
    if (!id) return "";
    return id.toString().replace(/['"\[\]]/g, "").trim();
}

function isSecondaryEntity(entId) {
    if (!entId) return false;
    var lower = entId.toLowerCase();
    var secondaryKeywords = [
        "battery", "battery_level", "voltage", "current", "power", "energy",
        "linkquality", "rssi", "lqi", "temperature", "humidity",
        "update_available", "identify", "ping", "signal_strength"
    ];
    var parts = lower.split(".");
    var name = parts.length > 1 ? parts[1] : parts[0];
    for (var i = 0; i < secondaryKeywords.length; i++) {
        var kw = secondaryKeywords[i];
        if (name === kw || name.endsWith("_" + kw) || name.startsWith(kw + "_")) {
            return true;
        }
    }
    return false;
}

function getDeviceTitle(entId, entObj, devId, haManager) {
    if (!entId) return "";
    if (haManager && devId) {
        var dev = haManager.getDeviceRaw ? haManager.getDeviceRaw(devId) : null;
        if (dev && dev.name_by_user) return dev.name_by_user;
        if (dev && dev.name) return dev.name;
    }
    if (entObj && entObj.attributes) {
        if (entObj.attributes.friendly_name) return entObj.attributes.friendly_name;
    }
    return entId;
}

function getAreaName(cleanId, haManager) {
    if (!haManager || !cleanId) return "";
    var devId = haManager.entityToDeviceMap ? (haManager.entityToDeviceMap[cleanId] || "") : "";
    var dev = (haManager.getDeviceRaw && devId) ? haManager.getDeviceRaw(devId) : null;
    var aId = (dev && dev.area_id) ? dev.area_id : (haManager.entityToAreaMap ? haManager.entityToAreaMap[cleanId] : null);
    if (!aId || !haManager.areasList) return "";
    for (var i = 0; i < haManager.areasList.length; i++) {
        if (haManager.areasList[i].area_id === aId || haManager.areasList[i].id === aId) {
            return haManager.areasList[i].name || "";
        }
    }
    return "";
}

function getBinarySensorStateTitle(state, deviceClass) {
    var isOn = (state === "on");
    var dc = (deviceClass || "").toLowerCase();
    if (dc === "door" || dc === "garage_door" || dc === "window" || dc === "opening") {
        return isOn ? tr("Open") : tr("Closed");
    }
    if (dc === "lock") {
        return isOn ? tr("Unlocked") : tr("Locked");
    }
    if (dc === "moisture") {
        return isOn ? tr("Wet") : tr("Dry");
    }
    if (dc === "gas" || dc === "smoke" || dc === "carbon_monoxide") {
        return isOn ? tr("Detected") : tr("Clear");
    }
    if (dc === "motion" || dc === "occupancy" || dc === "presence") {
        return isOn ? tr("Motion") : tr("No motion");
    }
    if (dc === "problem" || dc === "safety" || dc === "tamper") {
        return isOn ? tr("Problem") : tr("OK");
    }
    if (dc === "plug" || dc === "power" || dc === "connectivity") {
        return isOn ? tr("Connected") : tr("Disconnected");
    }
    if (dc === "battery" || dc === "battery_charging") {
        return isOn ? tr("Low battery") : tr("Normal");
    }
    if (dc === "sound" || dc === "vibration") {
        return isOn ? tr("Detected") : tr("Quiet");
    }
    if (dc === "running") {
        return isOn ? tr("Running") : tr("Stopped");
    }
    if (dc === "update") {
        return isOn ? tr("Update available") : tr("Up to date");
    }
    return isOn ? tr("Active") : tr("Inactive");
}

// Icon helpers return a bare key; QML resolves it to contents/icons/<key>.svg
// (see iconUrl()). Keeping URL resolution in QML avoids context issues in JS.
function getBinarySensorIcon(deviceClass, isOn) {
    var dc = (deviceClass || "").toLowerCase();
    if (dc === "door" || dc === "garage_door" || dc === "opening") return isOn ? "door-open" : "door";
    if (dc === "window") return "window";
    if (dc === "moisture") return "humidity";
    if (dc === "smoke" || dc === "gas" || dc === "carbon_monoxide" || dc === "problem" || dc === "safety" || dc === "tamper") return "alert";
    if (dc === "motion" || dc === "occupancy" || dc === "presence" || dc === "moving") return "motion";
    if (dc === "lock") return isOn ? "lock-open" : "lock";
    if (dc === "battery" || dc === "battery_charging") return "battery";
    if (dc === "connectivity") return "wifi";
    if (dc === "plug" || dc === "power") return "plug";
    if (dc === "light") return "sun";
    if (dc === "heat" || dc === "cold") return "temperature";
    if (dc === "update") return "update";
    if (dc === "running") return "play";
    return "sensor";
}

function getSensorIcon(deviceClass, unit) {
    var dc = (deviceClass || "").toLowerCase();
    var u = (unit || "").toString();
    if (dc === "temperature" || u === "°C" || u === "°F") return "temperature";
    if (dc === "humidity" || dc === "moisture") return "humidity";
    if (dc === "battery") return "battery";
    if (dc === "power" || dc === "energy" || dc === "voltage" || dc === "current" || dc === "apparent_power" || dc === "power_factor") return "bolt";
    if (dc === "illuminance") return "sun";
    if (dc === "carbon_dioxide" || dc === "pm25" || dc === "pm10" || dc === "pm1" || dc === "volatile_organic_compounds" || dc === "aqi" || dc === "pressure" || dc === "atmospheric_pressure") return "air";
    if (dc === "signal_strength") return "wifi";
    if (dc === "timestamp" || dc === "date" || dc === "duration") return "calendar";
    if (dc === "water" || dc === "gas" || dc === "volume") return "humidity";
    return "sensor";
}

function getDomainIcon(domain, state, attributes) {
    var dom = (domain || "").toLowerCase();
    var attrs = attributes || {};
    switch (dom) {
    case "light": return state === "on" ? "lightbulb-on" : "lightbulb";
    case "switch":
    case "outlet": return "plug";
    case "input_boolean": return "toggle";
    case "climate": return "thermostat";
    case "fan": return "fan";
    case "cover": return "blinds";
    case "lock": return state === "locked" ? "lock" : "lock-open";
    case "binary_sensor": return getBinarySensorIcon(attrs.device_class, state === "on");
    case "sensor": return getSensorIcon(attrs.device_class, attrs.unit_of_measurement);
    case "media_player": return (attrs.device_class === "tv") ? "tv" : "speaker";
    case "scene": return "play";
    case "script": return "script";
    case "automation": return "automation";
    case "button":
    case "input_button": return "button";
    case "vacuum": return "vacuum";
    case "camera": return "camera";
    case "person":
    case "device_tracker": return "person";
    case "weather": return "weather";
    case "valve": return "valve";
    case "siren": return "siren";
    case "alarm_control_panel": return "shield";
    case "lawn_mower": return "mower";
    case "humidifier": return "humidity";
    case "water_heater": return "water-heater";
    case "update": return "update";
    case "number":
    case "input_number": return "number";
    case "select":
    case "input_select": return "list";
    case "calendar":
    case "input_datetime": return "calendar";
    case "sun": return "sun";
    case "zone": return "home";
    }
    return "device";
}

// Entity label for lists: friendly_name is unique per entity, while the
// device name is shared by every entity of the device.
function getEntityTitle(entId, entObj) {
    if (entObj && entObj.attributes && entObj.attributes.friendly_name) return entObj.attributes.friendly_name;
    if (!entId) return "";
    var n = entId.split(".").slice(1).join(".").replace(/_/g, " ");
    return n.charAt(0).toUpperCase() + n.slice(1);
}

function getStatusDetailsText(cleanId, entObj, devId, haManager) {
    if (!entObj || entObj.state === undefined || entObj.state === "unavailable" || entObj.state === "unknown") {
        return tr("Unavailable");
    }
    var dom = cleanId ? cleanId.split(".")[0] : "";
    var state = entObj.state;
    var attrs = entObj.attributes || {};

    if (dom === "switch" || dom === "light" || dom === "outlet" || dom === "fan" || dom === "input_boolean") {
        return (state === "on") ? tr("On") : tr("Off");
    }
    if (dom === "cover") {
        var pos = attrs.current_position;
        if (pos !== undefined) {
            return pos + "% • " + (state === "open" ? tr("Open") : tr("Closed"));
        }
        return (state === "open") ? tr("Open") : tr("Closed");
    }
    if (dom === "lock") {
        return (state === "locked") ? tr("Locked") : tr("Unlocked");
    }
    if (dom === "climate") {
        var curT = attrs.current_temperature;
        var hvac = attrs.hvac_action || state;
        var hvacTranslate = {
            "heating": tr("Heating"),
            "cooling": tr("Cooling"),
            "idle": tr("Idle"),
            "off": tr("Off"),
            "fan": tr("Fan")
        };
        var hvacText = hvacTranslate[hvac] || hvac;
        return (curT !== undefined ? curT + "°C • " : "") + hvacText;
    }
    if (dom === "binary_sensor") {
        return getBinarySensorStateTitle(state, attrs.device_class);
    }
    if (dom === "vacuum") {
        if (state === "cleaning") return tr("Cleaning");
        if (state === "docked") return tr("Docked");
        if (state === "returning") return tr("Returning");
        if (state === "paused") return tr("Paused");
        if (state === "error") return tr("Error");
        return state;
    }
    if (dom === "media_player") {
        if (state === "playing") return tr("Playing");
        if (state === "paused") return tr("Paused");
        if (state === "idle") return tr("Inactive");
        if (state === "off") return tr("Off");
        return state;
    }
    if (dom === "person") {
        return (state === "home") ? tr("Home") : tr("Away");
    }
    if (dom === "sensor") {
        var u = attrs.unit_of_measurement ? " " + attrs.unit_of_measurement : "";
        if (attrs.device_class === "timestamp") {
            var ts = new Date(state);
            if (!isNaN(ts.getTime())) return formatLastChangedDate(state, state);
        }
        var num = Number(state);
        if (state !== "" && !isNaN(num) && String(state).indexOf(".") !== -1) {
            var decimals = Math.abs(num) >= 100 ? 0 : 1;
            return num.toFixed(decimals).replace(".", ",") + u;
        }
        return state + u;
    }
    if (dom === "alarm_control_panel") {
        if (state === "disarmed") return tr("Disarmed");
        if (state === "armed_home") return tr("Armed (home)");
        if (state === "armed_away") return tr("Armed (away)");
        if (state === "armed_night") return tr("Armed (night)");
        if (state === "triggered") return tr("Triggered!");
        return state;
    }
    if (dom === "valve") {
        return (state === "open") ? tr("Open") : tr("Closed");
    }
    if (dom === "lawn_mower") {
        if (state === "mowing") return tr("Mowing");
        if (state === "docked") return tr("Docked");
        if (state === "paused") return tr("Paused");
        if (state === "error") return tr("Error");
        return state;
    }
    if (dom === "siren") {
        return (state === "on") ? tr("On") : tr("Off");
    }

    if (dom === "automation" || dom === "input_boolean") return (state === "on") ? tr("Enabled") : tr("Disabled");
    if (dom === "scene" || dom === "button" || dom === "input_button") return tr("Activate");
    if (dom === "script") return (state === "on") ? tr("Running") : tr("Ready");
    if (dom === "update") return (state === "on") ? tr("Update available") : tr("Up to date");
    if (dom === "weather") {
        var wt = { "sunny": tr("Sunny"), "clear-night": tr("Clear night"), "cloudy": tr("Cloudy"), "partlycloudy": tr("Partly cloudy"),
                   "rainy": tr("Rainy"), "pouring": tr("Pouring"), "snowy": tr("Snowy"), "fog": tr("Fog"), "windy": tr("Windy"),
                   "lightning": tr("Lightning"), "lightning-rainy": tr("Lightning"), "hail": tr("Hail"), "exceptional": tr("Exceptional") };
        var t = attrs.temperature !== undefined ? " • " + attrs.temperature + "°" : "";
        return (wt[state] || state) + t;
    }
    if (dom === "device_tracker") return (state === "home") ? tr("Home") : (state === "not_home" ? tr("Away") : state);

    var unit = attrs.unit_of_measurement ? " " + attrs.unit_of_measurement : "";
    return state + unit;
}

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

    if (diffDay > 0) return tr("%1d", diffDay);
    if (diffHour > 0) return tr("%1h", diffHour);
    if (diffMin > 0) return tr("%1m", diffMin);
    return tr("%1s", diffSec);
}

function formatLastChangedDate(lastChanged, fallback) {
    if (!lastChanged) return fallback || "—";
    var d = new Date(lastChanged);
    if (isNaN(d.getTime())) return fallback || "—";
    return Qt.formatDateTime(d, "hh:mm, d MMM");
}
