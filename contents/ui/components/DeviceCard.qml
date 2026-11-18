import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "../../code/ha_helpers.js" as HAHelpers

PlasmaComponents3.ItemDelegate {
    id: cardRoot

    property string entityId: ""
    property var haManager: null
    property bool desktopMode: false

    signal configureRequested()
    signal openDetailsRequested(string entId)

    implicitWidth: desktopMode ? Kirigami.Units.gridUnit * 9 : (contentItem ? contentItem.implicitWidth + leftPadding + rightPadding : Kirigami.Units.gridUnit * 18)
    implicitHeight: desktopMode ? Kirigami.Units.gridUnit * 5.5 : (contentItem ? contentItem.implicitHeight + topPadding + bottomPadding : Kirigami.Units.gridUnit * 3.2)

    readonly property string cleanId: HAHelpers.cleanEntityId(entityId)
    readonly property int revision: haManager ? haManager.entitiesRevision : 0

    readonly property var entityObj: {
        var rev = cardRoot.revision;
        return haManager ? haManager.getEntity(cleanId) : null;
    }

    readonly property string deviceId: haManager ? (haManager.entityToDeviceMap[cleanId] || "") : ""
    readonly property string domain: cleanId ? cleanId.split(".")[0] : ""
    readonly property var attributes: entityObj && entityObj.attributes ? entityObj.attributes : ({})
    readonly property string rawState: entityObj ? entityObj.state : "unavailable"
    readonly property bool isUnavailable: rawState === "unavailable" || rawState === "unknown" || !entityObj

    readonly property bool isOn: !isUnavailable && (rawState === "on" || rawState === "home" || rawState === "open" || rawState === "playing" || rawState === "unlocked")
    readonly property bool isEmptyDesktopState: desktopMode && (!cleanId || cleanId.length === 0 || !entityObj)

    readonly property var favoriteEntitiesList: {
        var raw = (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.favoriteEntities || "") : "";
        if (!raw) return [];
        try {
            var parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                return parsed.map(function(item) {
                    return HAHelpers.cleanEntityId(item);
                });
            }
        } catch(e) {}
        return [];
    }

    readonly property bool isFavorite: favoriteEntitiesList.indexOf(cardRoot.cleanId) !== -1

    function toggleFavoriteInPlasmoid() {
        if (!cardRoot.cleanId) return;
        if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) {
            var cleaned = favoriteEntitiesList.slice();
            var idx = cleaned.indexOf(cardRoot.cleanId);
            if (idx !== -1) {
                cleaned.splice(idx, 1);
            } else {
                cleaned.push(cardRoot.cleanId);
            }
            Plasmoid.configuration.favoriteEntities = JSON.stringify(cleaned);
        }
    }

    readonly property var registryInfo: {
        var rev = cardRoot.revision;
        return cardRoot.haManager && cardRoot.haManager.getEntityRegistry
            ? cardRoot.haManager.getEntityRegistry(cardRoot.cleanId)
            : null;
    }

    readonly property string areaName: {
        var rev = cardRoot.revision;
        return HAHelpers.getAreaName(cardRoot.cleanId, cardRoot.haManager);
    }

    readonly property string deviceTitle: {
        var rev = cardRoot.revision;
        return HAHelpers.getEntityTitle(cardRoot.cleanId, cardRoot.entityObj, cardRoot.registryInfo, cardRoot.haManager);
    }

    readonly property string deviceSubtitle: {
        var rev = cardRoot.revision;
        if (!cardRoot.deviceId || !cardRoot.haManager) return "";
        var dev = cardRoot.haManager.getDeviceRaw(cardRoot.deviceId);
        if (!dev) return "";
        var name = HAHelpers.getDeviceDisplayName(dev, "");
        return name === cardRoot.deviceTitle ? "" : name;
    }

    readonly property bool isToggleable: ["light", "switch", "input_boolean", "fan", "outlet"].indexOf(domain) !== -1
    readonly property bool isActionable: ["script", "scene", "button", "automation", "input_button"].indexOf(domain) !== -1
    readonly property bool isLock: domain === "lock"

    readonly property color statusTextColor: {
        if (isUnavailable) return Kirigami.Theme.disabledTextColor;
        if (domain === "binary_sensor") {
            var devClass = attributes.device_class || "";
            if (["moisture", "smoke", "gas", "safety"].indexOf(devClass) !== -1) {
                return isOn ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor;
            }
            return isOn ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor;
        }
        if (isToggleable || domain === "lock" || domain === "cover") {
            return isOn ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor;
        }
        return Kirigami.Theme.textColor;
    }

    readonly property string statusDetailsText: {
        var rev = cardRoot.revision;
        return HAHelpers.getStatusDetailsText(cardRoot.cleanId, cardRoot.entityObj, cardRoot.deviceId, cardRoot.haManager);
    }

    Layout.fillWidth: true
    Layout.fillHeight: desktopMode
    width: parent ? parent.width : 0

    leftPadding: desktopMode ? Kirigami.Units.smallSpacing * 1.5 : Kirigami.Units.mediumSpacing * 1.2
    rightPadding: desktopMode ? Kirigami.Units.smallSpacing * 1.5 : Kirigami.Units.gridUnit * 1.5
    topPadding: desktopMode ? Kirigami.Units.smallSpacing * 1.5 : Kirigami.Units.smallSpacing * 1.2
    bottomPadding: desktopMode ? Kirigami.Units.smallSpacing * 1.5 : Kirigami.Units.smallSpacing * 1.2

    background: Rectangle {
        radius: 14
        color: cardRoot.hovered
            ? Qt.alpha(Kirigami.Theme.textColor, 0.08)
            : Qt.alpha(Kirigami.Theme.textColor, 0.03)
        border.color: cardRoot.isEmptyDesktopState
            ? (cardRoot.hovered ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12))
            : (cardRoot.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.20) : Qt.alpha(Kirigami.Theme.textColor, 0.08))
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    onClicked: {
        if (isEmptyDesktopState) {
            cardRoot.configureRequested();
            return;
        }
        if (cardRoot.cleanId) {
            cardRoot.openDetailsRequested(cardRoot.cleanId);
        }
    }

    contentItem: Loader {
        sourceComponent: cardRoot.isEmptyDesktopState
            ? emptyDesktopComponent
            : (cardRoot.desktopMode ? desktopLayoutComponent : listLayoutComponent)
    }

    Component {
        id: emptyDesktopComponent
        Item {
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cardRoot.configureRequested()
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                width: parent.width - Kirigami.Units.gridUnit

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    source: "list-add-symbolic"
                    implicitWidth: Math.round(Kirigami.Units.gridUnit * 1.3)
                    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.3)
                    color: Kirigami.Theme.highlightColor
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("No device selected")
                    font.bold: true
                    font.pointSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Click to configure")
                    font.pointSize: 7.5
                    opacity: 0.65
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }

    Component {
        id: listLayoutComponent

        RowLayout {
            spacing: Kirigami.Units.mediumSpacing
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    visible: cardRoot.areaName.length > 0
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: areaLabel.implicitWidth + Kirigami.Units.smallSpacing * 1.8
                        implicitHeight: areaLabel.implicitHeight + 4
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                        border.width: 1

                        PlasmaComponents3.Label {
                            id: areaLabel
                            anchors.centerIn: parent
                            text: cardRoot.areaName.toUpperCase()
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.68
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                }

                MarqueeLabel {
                    text: cardRoot.deviceTitle
                    isBold: cardRoot.isOn
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    visible: cardRoot.deviceSubtitle.length > 0
                    text: cardRoot.deviceSubtitle
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.76
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 5
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        visible: !cardRoot.isUnavailable
                        color: cardRoot.statusTextColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        text: cardRoot.statusDetailsText
                        font.weight: cardRoot.isOn ? Font.DemiBold : Font.Normal
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                        color: cardRoot.statusTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                PlasmaComponents3.Switch {
                    visible: cardRoot.isToggleable
                    enabled: !cardRoot.isUnavailable
                    Layout.alignment: Qt.AlignVCenter

                    Binding on checked {
                        value: cardRoot.isOn
                    }

                    onToggled: {
                        if (!cardRoot.haManager || !cardRoot.cleanId || cardRoot.isUnavailable) return;
                        var service = checked ? "turn_on" : "turn_off";
                        haManager.callService(cardRoot.domain, service, cleanId, {});
                    }
                }

                PlasmaComponents3.ToolButton {
                    visible: cardRoot.isActionable
                    icon.name: "media-playback-start-symbolic"
                    enabled: !cardRoot.isUnavailable
                    Layout.alignment: Qt.AlignVCenter

                    onClicked: {
                        if (!cardRoot.haManager || !cardRoot.cleanId || cardRoot.isUnavailable) return;
                        if (cardRoot.domain === "script") cardRoot.haManager.callService("script", cardRoot.cleanId.split(".")[1], cardRoot.cleanId, {});
                        else if (cardRoot.domain === "scene") cardRoot.haManager.callService("scene", "turn_on", cardRoot.cleanId, {});
                        else if (cardRoot.domain === "automation") cardRoot.haManager.callService("automation", "trigger", cardRoot.cleanId, {});
                        else if (cardRoot.domain === "button") cardRoot.haManager.callService("button", "press", cardRoot.cleanId, {});
                        else if (cardRoot.domain === "input_button") cardRoot.haManager.callService("input_button", "press", cardRoot.cleanId, {});
                    }
                }

                PlasmaComponents3.ToolButton {
                    visible: cardRoot.isLock
                    icon.name: cardRoot.isOn ? "object-unlocked-symbolic" : "object-locked-symbolic"
                    enabled: !cardRoot.isUnavailable
                    Layout.alignment: Qt.AlignVCenter

                    onClicked: {
                        if (!cardRoot.haManager || !cardRoot.cleanId || cardRoot.isUnavailable) return;
                        var service = cardRoot.isOn ? "lock" : "unlock";
                        haManager.callService("lock", service, cleanId, {});
                    }
                }

                MouseArea {
                    implicitWidth: Kirigami.Units.gridUnit * 1.8
                    implicitHeight: Kirigami.Units.gridUnit * 1.8
                    Layout.alignment: Qt.AlignVCenter
                    cursorShape: Qt.PointingHandCursor

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: cardRoot.isFavorite ? "starred-symbolic" : "non-starred-symbolic"
                        color: cardRoot.isFavorite ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                        implicitWidth: Kirigami.Units.gridUnit * 1.4
                        implicitHeight: Kirigami.Units.gridUnit * 1.4
                    }

                    onClicked: {
                        cardRoot.toggleFavoriteInPlasmoid();
                    }
                }
            }
        }
    }

    Component {
        id: desktopLayoutComponent

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            anchors.fill: parent

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    visible: cardRoot.areaName.length > 0
                    implicitWidth: areaLabelDesk.implicitWidth + Kirigami.Units.smallSpacing * 1.8
                    implicitHeight: areaLabelDesk.implicitHeight + 4
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                    border.width: 1

                    PlasmaComponents3.Label {
                        id: areaLabelDesk
                        anchors.centerIn: parent
                        text: cardRoot.areaName.toUpperCase()
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.68
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }

            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true

                MarqueeLabel {
                    text: cardRoot.deviceTitle
                    isBold: true
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    visible: cardRoot.deviceSubtitle.length > 0
                    text: cardRoot.deviceSubtitle
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.76
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 5
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        visible: !cardRoot.isUnavailable
                        color: cardRoot.statusTextColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        text: cardRoot.statusDetailsText
                        font.weight: cardRoot.isOn ? Font.DemiBold : Font.Normal
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                        color: cardRoot.statusTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Switch {
                    visible: cardRoot.isToggleable
                    enabled: !cardRoot.isUnavailable

                    Binding on checked {
                        value: cardRoot.isOn
                    }

                    onToggled: {
                        if (!cardRoot.haManager || !cardRoot.cleanId || cardRoot.isUnavailable) return;
                        var service = checked ? "turn_on" : "turn_off";
                        haManager.callService(cardRoot.domain, service, cleanId, {});
                    }
                }

                PlasmaComponents3.ToolButton {
                    visible: cardRoot.isActionable
                    icon.name: "media-playback-start-symbolic"
                    enabled: !cardRoot.isUnavailable
                    onClicked: {
                        if (!cardRoot.haManager || !cardRoot.cleanId || cardRoot.isUnavailable) return;
                        if (cardRoot.domain === "script") cardRoot.haManager.callService("script", cardRoot.cleanId.split(".")[1], cardRoot.cleanId, {});
                        else if (cardRoot.domain === "scene") cardRoot.haManager.callService("scene", "turn_on", cardRoot.cleanId, {});
                        else if (cardRoot.domain === "automation") cardRoot.haManager.callService("automation", "trigger", cardRoot.cleanId, {});
                        else if (cardRoot.domain === "button") cardRoot.haManager.callService("button", "press", cardRoot.cleanId, {});
                        else if (cardRoot.domain === "input_button") cardRoot.haManager.callService("input_button", "press", cardRoot.cleanId, {});
                    }
                }

                PlasmaComponents3.ToolButton {
                    visible: cardRoot.isLock
                    icon.name: cardRoot.isOn ? "object-unlocked-symbolic" : "object-locked-symbolic"
                    enabled: !cardRoot.isUnavailable
                    onClicked: {
                        if (!cardRoot.haManager || !cardRoot.cleanId || cardRoot.isUnavailable) return;
                        var service = cardRoot.isOn ? "lock" : "unlock";
                        haManager.callService("lock", service, cleanId, {});
                    }
                }
            }
        }
    }
}
