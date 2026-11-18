import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../code/ha_helpers.js" as HAHelpers

Item {
    id: dashboardCard

    property string entityId: ""
    property var haManager: null

    signal openDetailsRequested(string entId)
    signal configureRequested()

    readonly property string cleanId: HAHelpers.cleanEntityId(entityId)
    readonly property int revision: haManager ? haManager.entitiesRevision : 0
    readonly property var entityObj: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        return haManager ? haManager.getEntity(cleanId) : null;
    }
    readonly property var registryInfo: {
        return haManager && haManager.getEntityRegistry ? haManager.getEntityRegistry(cleanId) : null;
    }
    readonly property string domain: cleanId ? cleanId.split(".")[0] : ""
    readonly property string title: {
        return HAHelpers.getEntityTitle(cleanId, entityObj, registryInfo, haManager);
    }
    readonly property string areaName: {
        return HAHelpers.getAreaName(cleanId, haManager);
    }
    readonly property string statusText: {
        return HAHelpers.getStatusDetailsText(cleanId, entityObj, haManager && haManager.entityToDeviceMap ? (haManager.entityToDeviceMap[cleanId] || "") : "", haManager);
    }
    readonly property bool isUnavailable: !entityObj || entityObj.state === "unavailable" || entityObj.state === "unknown"
    readonly property bool isOn: !isUnavailable && (entityObj.state === "on" || entityObj.state === "home" || entityObj.state === "open" || entityObj.state === "playing" || entityObj.state === "unlocked")
    readonly property bool isToggleable: ["switch", "light", "fan", "input_boolean", "outlet"].indexOf(domain) !== -1
    readonly property bool isLock: domain === "lock"

    implicitWidth: Kirigami.Units.gridUnit * 9
    implicitHeight: contentCol.implicitHeight + topPadding + bottomPadding
    Layout.fillWidth: true

    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    leftPadding: Kirigami.Units.smallSpacing
    rightPadding: Kirigami.Units.smallSpacing

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (cleanId) dashboardCard.openDetailsRequested(cleanId);
            else dashboardCard.configureRequested();
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: isUnavailable ? "view-list-symbolic" : (isOn ? "media-playback-start-symbolic" : "media-playback-pause-symbolic")
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: isUnavailable ? Kirigami.Theme.disabledTextColor : (isOn ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor)
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: title
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: isUnavailable
                        ? i18n("Unavailable")
                        : statusText
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                    color: isUnavailable ? Kirigami.Theme.disabledTextColor : (isOn ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor)
                    font.bold: isOn
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        PlasmaComponents3.Label {
            visible: areaName.length > 0
            text: areaName.toUpperCase()
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.70
            color: Kirigami.Theme.disabledTextColor
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Item { Layout.fillWidth: true }

            PlasmaComponents3.Switch {
                visible: isToggleable
                enabled: !isUnavailable
                checked: isOn
                onToggled: {
                    if (!haManager || !entityObj || isUnavailable) return;
                    haManager.callService(domain, checked ? "turn_on" : "turn_off", cleanId, {});
                }
            }

            PlasmaComponents3.ToolButton {
                visible: isLock
                icon.name: isOn ? "object-unlocked-symbolic" : "object-locked-symbolic"
                enabled: !isUnavailable
                onClicked: {
                    if (!haManager || !entityObj || isUnavailable) return;
                    haManager.callService("lock", isOn ? "lock" : "unlock", cleanId, {});
                }
            }
        }
    }
}
