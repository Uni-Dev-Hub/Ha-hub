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
        return isOn ? "Open" : "Closed";
    }
    if (dc === "lock") {
        return isOn ? "Unlocked" : "Locked";
    }
    if (dc === "moisture") {
        return isOn ? "Wet" : "Dry";
    }
    if (dc === "gas" || dc === "smoke" || dc === "carbon_monoxide") {
        return isOn ? "Detected" : "Clear";
    }
    if (dc === "motion" || dc === "occupancy" || dc === "presence") {
        return isOn ? "Detected" : "Clear";
    }
    if (dc === "problem" || dc === "safety" || dc === "tamper") {
        return isOn ? "Problem" : "OK";
    }
    if (dc === "plug" || dc === "power" || dc === "connectivity") {
        return isOn ? "Connected" : "Disconnected";
    }
    if (dc === "battery" || dc === "battery_charging") {
        return isOn ? "Low" : "Normal";
    }
    if (dc === "sound" || dc === "vibration") {
        return isOn ? "Detected" : "Clear";
    }
    if (dc === "running") {
        return isOn ? "Running" : "Stopped";
    }
    if (dc === "update") {
        return isOn ? "Update available" : "Up to date";
    }
    return isOn ? "On" : "Off";
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
        return "dialog-warning-symbolic";
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

function getStatusDetailsText(cleanId, entObj, devId, haManager) {
    if (!entObj || entObj.state === undefined || entObj.state === "unavailable" || entObj.state === "unknown") {
        return "Unavailable";
    }
    var dom = cleanId ? cleanId.split(".")[0] : "";
    var state = entObj.state;
    var attrs = entObj.attributes || {};

    if (dom === "switch" || dom === "light" || dom === "outlet" || dom === "fan" || dom === "input_boolean") {
        return (state === "on") ? "On" : "Off";
    }
    if (dom === "cover") {
        var pos = attrs.current_position;
        if (pos !== undefined) {
            return pos + "% • " + (state === "open" ? "Open" : "Closed");
        }
        return (state === "open") ? "Open" : "Closed";
    }
    if (dom === "lock") {
        return (state === "locked") ? "Locked" : "Unlocked";
    }
    if (dom === "climate") {
        var curT = attrs.current_temperature;
        var hvac = attrs.hvac_action || state;
        return (curT !== undefined ? curT + "°C • " : "") + hvac;
    }
    if (dom === "binary_sensor") {
        return getBinarySensorStateTitle(state, attrs.device_class);
    }
    if (dom === "vacuum") {
        if (state === "cleaning") return "Cleaning";
        if (state === "docked") return "Docked";
        if (state === "returning") return "Returning";
        if (state === "paused") return "Paused";
        if (state === "error") return "Error";
        return state;
    }
    if (dom === "media_player") {
        if (state === "playing") return "Playing";
        if (state === "paused") return "Paused";
        if (state === "idle") return "Idle";
        if (state === "off") return "Off";
        return state;
    }
    if (dom === "person") {
        return (state === "home") ? "Home" : "Away";
    }
    if (dom === "sensor") {
        var u = attrs.unit_of_measurement ? " " + attrs.unit_of_measurement : "";
        return state + u;
    }
    if (dom === "alarm_control_panel") {
        if (state === "disarmed") return "Disarmed";
        if (state === "armed_home") return "Armed Home";
        if (state === "armed_away") return "Armed Away";
        if (state === "armed_night") return "Armed Night";
        if (state === "triggered") return "Triggered";
        return state;
    }
    if (dom === "valve") {
        return (state === "open") ? "Open" : "Closed";
    }
    if (dom === "lawn_mower") {
        if (state === "mowing") return "Mowing";
        if (state === "docked") return "Docked";
        if (state === "paused") return "Paused";
        if (state === "error") return "Error";
        return state;
    }
    if (dom === "siren") {
        return (state === "on") ? "On" : "Off";
    }

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

    if (diffDay > 0) return diffDay + "d";
    if (diffHour > 0) return diffHour + "h";
    if (diffMin > 0) return diffMin + "m";
    return diffSec + "s";
}

function formatLastChangedDate(lastChanged, fallback) {
    if (!lastChanged) return fallback || "—";
    var d = new Date(lastChanged);
    if (isNaN(d.getTime())) return fallback || "—";
    var hours = String(d.getHours()).padStart(2, "0");
    var mins = String(d.getMinutes()).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var month = monthNames[d.getMonth()];
    return hours + ":" + mins + ", " + day + " " + month;
}
