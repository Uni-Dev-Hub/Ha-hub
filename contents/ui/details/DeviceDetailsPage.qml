import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../../services" as Services
import "../../code/ha_helpers.js" as HAHelpers
import "sections" as Sections

PlasmaComponents3.Page {
    id: detailsPage

    property var haManager: null
    property string primaryEntityId: ""

    property bool optionsExpanded: false
    property bool infoExpanded: false

    signal backRequested()

    readonly property int revision: haManager ? haManager.entitiesRevision : 0

    readonly property string cleanId: HAHelpers.cleanEntityId(primaryEntityId)
    readonly property string deviceId: haManager && cleanId ? (haManager.entityToDeviceMap[cleanId] || "") : ""
    readonly property var deviceRaw: haManager && deviceId ? haManager.getDeviceRaw(deviceId) : null

    readonly property string primaryDomain: cleanId ? cleanId.split(".")[0] : ""
    readonly property var primaryEntityObj: {
        var rev = detailsPage.revision;
        return haManager ? haManager.getEntity(cleanId) : null;
    }

    readonly property string deviceName: {
        if (deviceRaw && deviceRaw.name) return deviceRaw.name;
        if (primaryEntityObj && primaryEntityObj.attributes && primaryEntityObj.attributes.friendly_name) return primaryEntityObj.attributes.friendly_name;
        return cleanId;
    }

    readonly property string areaName: {
        if (!haManager || !cleanId) return "";
        var aId = (deviceRaw && deviceRaw.area_id) ? deviceRaw.area_id : (haManager.entityToAreaMap ? haManager.entityToAreaMap[cleanId] : null);
        if (!aId || !haManager.areasList) return "";
        for (var i = 0; i < haManager.areasList.length; i++) {
            if (haManager.areasList[i].area_id === aId) return haManager.areasList[i].name || "";
        }
        return "";
    }

    readonly property var allDeviceEntities: {
        if (deviceId && haManager && haManager.deviceToEntitiesMap && haManager.deviceToEntitiesMap[deviceId]) {
            return haManager.deviceToEntitiesMap[deviceId];
        }
        return cleanId ? [cleanId] : [];
    }

    readonly property string mainSwitchEntityId: {
        var rev = detailsPage.revision;
        var ent = haManager ? haManager.getEntity(cleanId) : null;
        var dom = cleanId ? cleanId.split(".")[0] : "";
        if (ent && (dom === "switch" || dom === "outlet" || dom === "light" || dom === "fan") && !HAHelpers.isSecondaryEntity(cleanId)) {
            return cleanId;
        }
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var eId = allDeviceEntities[i];
            var d = eId.split(".")[0];
            if ((d === "switch" || d === "outlet" || d === "light" || d === "fan") && !HAHelpers.isSecondaryEntity(eId)) {
                var reg = haManager && haManager.entityRegistryMap ? haManager.entityRegistryMap[eId] : null;
                if (reg && (reg.category === "config" || reg.category === "diagnostic")) continue;
                return eId;
            }
        }
        return "";
    }

    readonly property var switchEntityObj: {
        var rev = detailsPage.revision;
        return mainSwitchEntityId ? haManager.getEntity(mainSwitchEntityId) : null;
    }

    readonly property bool isToggleable: mainSwitchEntityId.length > 0 || primaryDomain === "light" || primaryDomain === "fan"
    readonly property bool isTurnedOn: {
        var rev = detailsPage.revision;
        if (switchEntityObj) return switchEntityObj.state === "on";
        if ((primaryDomain === "light" || primaryDomain === "fan") && primaryEntityObj) return primaryEntityObj.state === "on";
        return false;
    }

    readonly property var powerEntityObj: {
        var rev = detailsPage.revision;
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var ent = haManager ? haManager.getEntity(allDeviceEntities[i]) : null;
            if (!ent) continue;
            var u = (ent.attributes && ent.attributes.unit_of_measurement) ? ent.attributes.unit_of_measurement.toLowerCase() : "";
            var dc = (ent.attributes && ent.attributes.device_class) ? ent.attributes.device_class.toLowerCase() : "";
            if (dc === "power" || u === "w" || u === "вт") return ent;
        }
        return null;
    }

    readonly property var voltageEntityObj: {
        var rev = detailsPage.revision;
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var ent2 = haManager ? haManager.getEntity(allDeviceEntities[i]) : null;
            if (!ent2) continue;
            var u2 = (ent2.attributes && ent2.attributes.unit_of_measurement) ? ent2.attributes.unit_of_measurement.toLowerCase() : "";
            var dc2 = (ent2.attributes && ent2.attributes.device_class) ? ent2.attributes.device_class.toLowerCase() : "";
            if (dc2 === "voltage" || u2 === "v" || u2 === "в") return ent2;
        }
        return null;
    }

    readonly property var currentEntityObj: {
        var rev = detailsPage.revision;
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var ent3 = haManager ? haManager.getEntity(allDeviceEntities[i]) : null;
            if (!ent3) continue;
            var u3 = (ent3.attributes && ent3.attributes.unit_of_measurement) ? ent3.attributes.unit_of_measurement.toLowerCase() : "";
            var dc3 = (ent3.attributes && ent3.attributes.device_class) ? ent3.attributes.device_class.toLowerCase() : "";
            if (dc3 === "current" || u3 === "a" || u3 === "а") return ent3;
        }
        return null;
    }

    readonly property string tempEntityId: {
        var rev = detailsPage.revision;
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var eId = allDeviceEntities[i];
            var ent = haManager ? haManager.getEntity(eId) : null;
            if (!ent) continue;
            var u = (ent.attributes && ent.attributes.unit_of_measurement) ? ent.attributes.unit_of_measurement.toLowerCase() : "";
            var dc = (ent.attributes && ent.attributes.device_class) ? ent.attributes.device_class.toLowerCase() : "";
            if (dc === "temperature" || u.indexOf("°") !== -1) return eId;
        }
        return "";
    }

    readonly property var tempEntityObj: {
        var rev = detailsPage.revision;
        return tempEntityId ? haManager.getEntity(tempEntityId) : null;
    }

    readonly property string humidityEntityId: {
        var rev = detailsPage.revision;
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var eId = allDeviceEntities[i];
            var ent = haManager ? haManager.getEntity(eId) : null;
            if (!ent) continue;
            var u = (ent.attributes && ent.attributes.unit_of_measurement) ? ent.attributes.unit_of_measurement.toLowerCase() : "";
            var dc = (ent.attributes && ent.attributes.device_class) ? ent.attributes.device_class.toLowerCase() : "";
            var fn = (ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name.toLowerCase() : "";
            if (dc === "battery" || fn.indexOf("батаре") !== -1 || fn.indexOf("battery") !== -1) continue;
            if (dc === "humidity" || u.indexOf("%") !== -1 || fn.indexOf("волог") !== -1) return eId;
        }
        return "";
    }

    readonly property var humidityEntityObj: {
        var rev = detailsPage.revision;
        return humidityEntityId ? haManager.getEntity(humidityEntityId) : null;
    }

    readonly property var batteryEntityObj: {
        var rev = detailsPage.revision;
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var ent = haManager ? haManager.getEntity(allDeviceEntities[i]) : null;
            if (!ent) continue;
            var dc = (ent.attributes && ent.attributes.device_class) ? ent.attributes.device_class.toLowerCase() : "";
            var fn = (ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name.toLowerCase() : "";
            if (dc === "battery" || fn.indexOf("батаре") !== -1 || fn.indexOf("battery") !== -1) return ent;
        }
        return null;
    }

    readonly property string energyEntityId: {
        var rev = detailsPage.revision;
        var scored = [];
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var eId = allDeviceEntities[i];
            var ent = haManager ? haManager.getEntity(eId) : null;
            if (!ent) continue;

            var reg = haManager && haManager.entityRegistryMap ? haManager.entityRegistryMap[eId] : null;
            if (reg && (reg.disabled || reg.hidden || reg.category === "diagnostic")) continue;

            var u = (ent.attributes && ent.attributes.unit_of_measurement) ? ent.attributes.unit_of_measurement.toLowerCase() : "";
            var dc = (ent.attributes && ent.attributes.device_class) ? ent.attributes.device_class.toLowerCase() : "";
            var sc = (ent.attributes && ent.attributes.state_class) ? ent.attributes.state_class.toLowerCase() : "";
            var eIdLow = eId.toLowerCase();
            var fnLow = (ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name.toLowerCase() : "";

            var isEnergy = (u === "kwh" || u === "wh" || u === "квт⋅год" || u === "квтг" || dc === "energy" || eIdLow.indexOf("energy") !== -1 || eIdLow.indexOf("енерг") !== -1);
            if (!isEnergy) continue;
            if (eIdLow.indexOf("produced") !== -1 || eIdLow.indexOf("reactive") !== -1 || eIdLow.indexOf("apparent") !== -1 || eIdLow.indexOf("export") !== -1 || fnLow.indexOf("генерац") !== -1) continue;

            var isDaily = (eIdLow.indexOf("daily") !== -1 || eIdLow.indexOf("today") !== -1 || fnLow.indexOf("добов") !== -1 || fnLow.indexOf("сьогодні") !== -1);

            var score = 100;
            if (sc === "total_increasing") score += 60;
            if (eIdLow.endsWith("_total_energy") || eIdLow.endsWith("_energy")) score += 50;
            if (fnLow.indexOf("загальн") !== -1 || fnLow.indexOf("total") !== -1) score += 40;
            if (isDaily) score -= 30;

            var val = (ent.state !== undefined && !isNaN(ent.state)) ? parseFloat(ent.state) : 0;
            scored.push({ id: eId, score: score, val: val });
        }

        scored.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score;
            return b.val - a.val;
        });

        return scored.length > 0 ? scored[0].id : "";
    }

    readonly property bool hasEnergyMonitoring: energyEntityId.length > 0 || powerEntityObj !== null

    readonly property string resolvedDeviceType: {
        if (primaryDomain === "light") return "light";
        if (primaryDomain === "media_player") return "media_player";
        if (primaryDomain === "cover") return "cover";
        if (primaryDomain === "valve") return "valve";
        if (primaryDomain === "lawn_mower") return "lawn_mower";
        if (primaryDomain === "siren") return "siren";
        if (primaryDomain === "person") return "person";
        if (primaryDomain === "fan") return "fan";
        if (primaryDomain === "vacuum") return "vacuum";
        if (primaryDomain === "lock") return "lock";
        if (primaryDomain === "water_heater") return "water_heater";
        if (primaryDomain === "humidifier") return "humidifier";
        if (primaryDomain === "alarm_control_panel") return "alarm_control_panel";
        if (primaryDomain === "camera") return "camera";
        if (primaryDomain === "weather") return "weather";
        if (primaryDomain === "climate") return "climate";
        if (tempEntityId.length > 0 || humidityEntityId.length > 0) return "climate_sensor";
        if (hasEnergyMonitoring) return "plug";
        if (primaryDomain === "switch" || primaryDomain === "outlet" || primaryDomain === "input_boolean") return "switch";
        if (primaryDomain === "binary_sensor") return "binary_sensor";
        return "generic";
    }

    readonly property var configEntitiesList: {
        var rev = detailsPage.revision;
        var list = [];
        for (var i = 0; i < allDeviceEntities.length; i++) {
            var eId2 = allDeviceEntities[i];
            var eDom = eId2.split(".")[0];
            var regInfo = haManager && haManager.entityRegistryMap ? haManager.entityRegistryMap[eId2] : null;

            if (eDom === "sensor" || eDom === "binary_sensor") continue;

            if (["select", "number", "text", "date", "time", "button", "update",
                 "input_select", "input_number", "input_text", "input_button"].indexOf(eDom) !== -1) {
                list.push(eId2);
                continue;
            }

            if ((eDom === "switch" || eDom === "input_boolean") && (HAHelpers.isSecondaryEntity(eId2, regInfo) || (regInfo && regInfo.category === "config"))) {
                if (eId2 !== detailsPage.mainSwitchEntityId) {
                    list.push(eId2);
                }
            }
        }
        return list;
    }

    // Additional controllable entities belonging to the same device. This is
    // what makes multi-gang switches, LocalTuya channels and similar devices
    // usable instead of showing only one "primary" entity per device.
    readonly property var channelsList: {
        var rev = detailsPage.revision;
        var list = [];
        var seen = {};

        for (var i = 0; i < allDeviceEntities.length; i++) {
            var eId = allDeviceEntities[i];
            if (!eId || eId === detailsPage.cleanId || seen[eId]) continue;

            var entry = haManager && haManager.getCatalogEntry ? haManager.getCatalogEntry(eId) : null;
            if (!entry) continue;
            if (entry.hidden || entry.disabled || entry.isConfig || entry.isDiagnostic) continue;

            var dom = entry.domain || eId.split(".")[0];
            if (!HAHelpers.isControlDomain(dom) && !HAHelpers.isActionDomain(dom)) continue;

            // A secondary action entity may also be listed in "Parameters &
            // Options"; avoid showing the same row twice.
            if (detailsPage.configEntitiesList.indexOf(eId) !== -1
                    && !HAHelpers.isControlDomain(dom)) continue;

            seen[eId] = true;
            list.push(eId);
        }

        return list;
    }

    function refreshStats() {
        if (energyEntityId.length > 0) {
            energyStatsService.fetchDeviceStatistics(energyEntityId);
        }
        if (tempEntityId.length > 0) {
            tempStatsService.fetchDeviceStatistics(tempEntityId);
        }
        if (humidityEntityId.length > 0) {
            humidityStatsService.fetchDeviceStatistics(humidityEntityId);
        }
        if (primaryDomain === "binary_sensor" && cleanId.length > 0) {
            binaryStatsService.fetchBinarySensorHistory(cleanId);
        }
        if (cleanId.length > 0) {
            historyStatsService.fetchHistory(cleanId);
        }
    }

    onEnergyEntityIdChanged: detailsPage.refreshStats()
    onTempEntityIdChanged: detailsPage.refreshStats()
    onHumidityEntityIdChanged: detailsPage.refreshStats()
    onCleanIdChanged: detailsPage.refreshStats()

    Services.HAStatisticsService {
        id: energyStatsService
        haManager: detailsPage.haManager
    }

    Services.HAStatisticsService {
        id: tempStatsService
        haManager: detailsPage.haManager
    }

    Services.HAStatisticsService {
        id: humidityStatsService
        haManager: detailsPage.haManager
    }

    Services.HAStatisticsService {
        id: binaryStatsService
        haManager: detailsPage.haManager
    }

    Services.HAHistoryService {
        id: historyStatsService
        haManager: detailsPage.haManager
    }

    header: PlasmaComponents3.ToolBar {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Kirigami.Units.smallSpacing * 1.5

        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                icon.name: "go-previous"
                text: i18n("Back")
                onClicked: detailsPage.backRequested()
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: detailsPage.deviceName
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.05
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 4
                    PlasmaComponents3.Label {
                        text: (detailsPage.areaName ? (detailsPage.areaName + " • ") : "") + (detailsPage.deviceRaw ? (detailsPage.deviceRaw.model || "Smart Device") : i18n("Device"))
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    PlasmaComponents3.Label {
                        visible: detailsPage.batteryEntityObj !== null
                        text: "• " + (detailsPage.batteryEntityObj ? (parseFloat(detailsPage.batteryEntityObj.state).toFixed(0) + "%") : "")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }

            PlasmaComponents3.Switch {
                visible: detailsPage.isToggleable

                Binding on checked {
                    value: detailsPage.isTurnedOn
                }

                onToggled: {
                    if (detailsPage.haManager) {
                        var eId = detailsPage.mainSwitchEntityId || detailsPage.cleanId;
                        var dom = eId ? eId.split(".")[0] : "switch";
                        detailsPage.haManager.callService(dom, checked ? "turn_on" : "turn_off", eId, {});
                    }
                }
            }
        }
    }

    PlasmaComponents3.ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width - Kirigami.Units.smallSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Kirigami.Units.smallSpacing * 1.4

            Sections.SwitchSection {
                visible: detailsPage.resolvedDeviceType === "switch"
                Layout.fillWidth: true
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.PlugSection {
                visible: detailsPage.resolvedDeviceType === "plug"
                Layout.fillWidth: true
                detailsPage: detailsPage
                energyStatsService: energyStatsService
            }

            Sections.ClimateSensorSection {
                visible: detailsPage.resolvedDeviceType === "climate_sensor"
                Layout.fillWidth: true
                detailsPage: detailsPage
                tempStatsService: tempStatsService
                humidityStatsService: humidityStatsService
            }

            Sections.LightSection {
                visible: detailsPage.resolvedDeviceType === "light"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.MediaPlayerSection {
                visible: detailsPage.resolvedDeviceType === "media_player"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.CoverSection {
                visible: detailsPage.resolvedDeviceType === "cover"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.ValveSection {
                visible: detailsPage.resolvedDeviceType === "valve"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.LawnMowerSection {
                visible: detailsPage.resolvedDeviceType === "lawn_mower"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.SirenSection {
                visible: detailsPage.resolvedDeviceType === "siren"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.PersonSection {
                visible: detailsPage.resolvedDeviceType === "person"
                detailsPage: detailsPage
            }

            Sections.FanSection {
                visible: detailsPage.resolvedDeviceType === "fan"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.VacuumSection {
                visible: detailsPage.resolvedDeviceType === "vacuum"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.LockSection {
                visible: detailsPage.resolvedDeviceType === "lock"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.WaterHeaterSection {
                visible: detailsPage.resolvedDeviceType === "water_heater"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.HumidifierSection {
                visible: detailsPage.resolvedDeviceType === "humidifier"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.AlarmControlPanelSection {
                visible: detailsPage.resolvedDeviceType === "alarm_control_panel"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.CameraSection {
                visible: detailsPage.resolvedDeviceType === "camera"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.WeatherSection {
                visible: detailsPage.resolvedDeviceType === "weather"
                detailsPage: detailsPage
            }

            Sections.ThermostatSection {
                visible: detailsPage.resolvedDeviceType === "climate"
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.BinarySensorSection {
                visible: detailsPage.resolvedDeviceType === "binary_sensor"
                Layout.fillWidth: true
                detailsPage: detailsPage
                binaryStatsService: binaryStatsService
            }

            Sections.GenericSection {
                visible: detailsPage.resolvedDeviceType === "generic"
                detailsPage: detailsPage
            }

            Sections.DeviceChannelsSection {
                Layout.fillWidth: true
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.DeviceOptionsSection {
                visible: detailsPage.configEntitiesList.length > 0
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Sections.HistorySection {
                detailsPage: detailsPage
                historyService: historyStatsService
            }

            Sections.DeviceInfoSection {
                detailsPage: detailsPage
                haManager: detailsPage.haManager
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }

    Component.onCompleted: {
        detailsPage.refreshStats();
    }
}
