import QtQuick
import org.kde.plasma.plasmoid
import "../../code/ha_helpers.js" as HAHelpers

// Shared, non-visual view-model for one Home Assistant entity.
// Used by CompactDeviceRow, CompactDeviceTile and GlassDeviceCard.
QtObject {
    id: st

    property string entityId: ""
    property var haManager: null

    readonly property string cleanId: HAHelpers.cleanEntityId(entityId)
    readonly property int revision: haManager ? haManager.entitiesRevision : 0

    readonly property var entityObj: {
        var rev = st.revision;
        return haManager ? haManager.getEntity(cleanId) : null;
    }

    readonly property string domain: cleanId ? cleanId.split(".")[0] : ""
    readonly property var attributes: entityObj && entityObj.attributes ? entityObj.attributes : ({})
    readonly property string rawState: entityObj ? String(entityObj.state) : "unavailable"
    readonly property bool isUnavailable: !entityObj || rawState === "unavailable" || rawState === "unknown"

    readonly property var activeStates: ["on", "open", "opening", "closing", "playing", "home", "unlocked", "unlocking",
        "heat", "cool", "heat_cool", "auto", "dry", "fan_only", "cleaning", "mowing", "returning",
        "armed_home", "armed_away", "armed_night", "armed_vacation", "armed_custom_bypass", "triggered", "buffering"]
    readonly property bool isOn: !isUnavailable && domain !== "sensor" && activeStates.indexOf(rawState) !== -1

    readonly property bool isValueEntity: ["sensor", "number", "input_number", "weather"].indexOf(domain) !== -1
        || (domain === "climate" && attributes.current_temperature !== undefined)

    readonly property string title: {
        var rev = st.revision;
        return HAHelpers.getEntityTitle(cleanId, entityObj);
    }

    readonly property string areaName: {
        var rev = st.revision;
        return haManager ? HAHelpers.getAreaName(cleanId, haManager) : "";
    }

    readonly property string statusText: {
        var rev = st.revision;
        return HAHelpers.getStatusDetailsText(cleanId, entityObj, "", haManager);
    }

    readonly property string lastChangedText: entityObj ? HAHelpers.formatTimeInState(entityObj.last_changed) : ""

    readonly property url iconUrl: Qt.resolvedUrl("../../icons/" + HAHelpers.getDomainIcon(domain, rawState, attributes) + ".svg")

    readonly property bool isToggleable: ["light", "switch", "input_boolean", "fan", "outlet", "siren", "humidifier", "automation"].indexOf(domain) !== -1
    readonly property bool isActionable: ["script", "scene", "button", "input_button"].indexOf(domain) !== -1
    readonly property bool hasQuickToggle: domain === "cover" || domain === "lock" || domain === "media_player"

    readonly property string quickToggleIcon: {
        if (domain === "cover") return (rawState === "open" || rawState === "opening") ? "go-down-symbolic" : "go-up-symbolic";
        if (domain === "lock") return rawState === "locked" ? "object-unlocked-symbolic" : "object-locked-symbolic";
        if (domain === "media_player") return rawState === "playing" ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
        return "";
    }
    readonly property string quickToggleTooltip: {
        if (domain === "cover") return (rawState === "open" || rawState === "opening") ? i18n("Close") : i18n("Open");
        if (domain === "lock") return rawState === "locked" ? i18n("Unlock") : i18n("Lock");
        if (domain === "media_player") return rawState === "playing" ? i18n("Pause") : i18n("Play");
        return "";
    }

    // Favorites
    readonly property var favoriteList: {
        var raw = Plasmoid.configuration.favoriteEntities || "";
        if (!raw) return [];
        try {
            var parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) return parsed.map(function(i) { return HAHelpers.cleanEntityId(i); });
        } catch (e) {}
        return [];
    }
    readonly property bool isFavorite: favoriteList.indexOf(cleanId) !== -1

    function toggleFavorite() {
        if (!cleanId) return;
        var list = favoriteList.slice();
        var idx = list.indexOf(cleanId);
        if (idx !== -1) list.splice(idx, 1); else list.push(cleanId);
        Plasmoid.configuration.favoriteEntities = JSON.stringify(list);
    }

    function setOn(on) {
        if (!haManager || isUnavailable) return;
        haManager.callService(domain, on ? "turn_on" : "turn_off", cleanId, {});
    }

    function toggle() {
        if (!haManager || isUnavailable) return;
        if (isToggleable) setOn(!isOn);
        else if (isActionable) activate();
        else if (hasQuickToggle) quickToggle();
    }

    function activate() {
        if (!haManager || isUnavailable) return;
        if (domain === "script") haManager.callService("script", "turn_on", cleanId, {});
        else if (domain === "scene") haManager.callService("scene", "turn_on", cleanId, {});
        else if (domain === "button" || domain === "input_button") haManager.callService(domain, "press", cleanId, {});
    }

    function quickToggle() {
        if (!haManager || isUnavailable) return;
        if (domain === "cover") haManager.callService("cover", (rawState === "open" || rawState === "opening") ? "close_cover" : "open_cover", cleanId, {});
        else if (domain === "lock") haManager.callService("lock", rawState === "locked" ? "unlock" : "lock", cleanId, {});
        else if (domain === "media_player") haManager.callService("media_player", "media_play_pause", cleanId, {});
    }
}
