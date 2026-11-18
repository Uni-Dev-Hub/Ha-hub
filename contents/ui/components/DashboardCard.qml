import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

Item {
    id: dashboardCard

    property string entityId: ""
    property var haManager: null

    // Appearance switches driven by the dashboard settings:
    // compact cards drop the extra rows, wide/tall cards bring them back.
    property bool compact: true
    property bool showArea: false
    property bool showTime: false

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
        // Depend on revision so a catalog rebuild (renamed entity, new
        // channel disambiguation) refreshes the card.
        var rev = dashboardCard.revision;
        var entry = haManager && haManager.getCatalogEntry ? haManager.getCatalogEntry(cleanId) : null;
        if (entry && entry.name) return entry.name;
        return HAHelpers.getEntityTitle(cleanId, entityObj, registryInfo, haManager);
    }
    readonly property string areaName: {
        return HAHelpers.getAreaName(cleanId, haManager);
    }
    readonly property string entityIcon: {
        if (entityObj && entityObj.attributes && entityObj.attributes.icon) {
            return entityObj.attributes.icon;
        }
        if (registryInfo && registryInfo.icon) return registryInfo.icon;
        return HAHelpers.getDomainIcon(domain);
    }
    readonly property string statusText: {
        return HAHelpers.getStatusDetailsText(cleanId, entityObj, haManager && haManager.entityToDeviceMap ? (haManager.entityToDeviceMap[cleanId] || "") : "", haManager, Loc.language);
    }
    readonly property string changedAgo: {
        if (!showTime || !entityObj) return "";
        return HAHelpers.formatTimeInState(entityObj.last_changed);
    }
    readonly property bool isUnavailable: !entityObj || entityObj.state === "unavailable" || entityObj.state === "unknown"
    readonly property bool isOn: !isUnavailable && (entityObj.state === "on" || entityObj.state === "home" || entityObj.state === "open" || entityObj.state === "playing" || entityObj.state === "unlocked")
    readonly property bool isToggleable: ["switch", "light", "fan", "input_boolean", "outlet"].indexOf(domain) !== -1
    readonly property bool isLock: domain === "lock"

    readonly property real cardPadding: compact ? Kirigami.Units.smallSpacing * 1.2 : Kirigami.Units.largeSpacing
    readonly property real cardRadius: Kirigami.Units.smallSpacing * 1.6

    implicitWidth: Kirigami.Units.gridUnit * 9
    implicitHeight: contentRow.implicitHeight + cardPadding * 2
    Layout.fillWidth: true

    // Card chrome: rounded panel, hairline border, soft shadow that lifts
    // slightly on hover so the grid reads as cards, not as plain text rows.
    Kirigami.ShadowedRectangle {
        id: cardBg
        anchors.fill: parent
        radius: dashboardCard.cardRadius
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.disabledTextColor, hoverArea.containsMouse ? 0.6 : 0.3)
        shadow.size: hoverArea.containsMouse ? 16 : 10
        shadow.color: Qt.alpha(Kirigami.Theme.shadowColor, hoverArea.containsMouse ? 0.4 : 0.25)
        shadow.yOffset: 2
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (dashboardCard.cleanId) dashboardCard.openDetailsRequested(dashboardCard.cleanId);
            else dashboardCard.configureRequested();
        }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: dashboardCard.cardPadding
        spacing: Kirigami.Units.smallSpacing * 1.4

        // Icon tile: entity icon on a state-tinted rounded square.
        Rectangle {
            id: iconTile
            implicitWidth: dashboardCard.compact
                ? Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2
                : Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
            implicitHeight: implicitWidth
            radius: dashboardCard.cardRadius
            color: dashboardCard.isUnavailable
                ? Qt.alpha(Kirigami.Theme.disabledTextColor, 0.10)
                : (dashboardCard.isOn ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22) : Qt.alpha(Kirigami.Theme.textColor, 0.07))
            Behavior on color { ColorAnimation { duration: 150 } }
            Layout.alignment: Qt.AlignVCenter

            Kirigami.Icon {
                anchors.centerIn: parent
                source: dashboardCard.entityIcon
                implicitWidth: dashboardCard.compact ? Kirigami.Units.iconSizes.small : Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                color: dashboardCard.isUnavailable
                    ? Kirigami.Theme.disabledTextColor
                    : (dashboardCard.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor)
            }
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true
            Layout.minimumWidth: 0

            PlasmaComponents3.Label {
                text: dashboardCard.title
                font.bold: true
                font.pointSize: dashboardCard.compact
                    ? Kirigami.Theme.smallFont.pointSize * 0.95
                    : Kirigami.Theme.defaultFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: dashboardCard.isUnavailable ? Loc.t("Unavailable") : dashboardCard.statusText
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                    color: dashboardCard.isUnavailable
                        ? Kirigami.Theme.disabledTextColor
                        : (dashboardCard.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                PlasmaComponents3.Label {
                    visible: dashboardCard.changedAgo.length > 0
                    text: dashboardCard.changedAgo
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                    color: Kirigami.Theme.disabledTextColor
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
            }

            PlasmaComponents3.Label {
                visible: dashboardCard.showArea && dashboardCard.areaName.length > 0
                text: dashboardCard.areaName.toUpperCase()
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                font.bold: true
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        PlasmaComponents3.Switch {
            visible: dashboardCard.isToggleable
            enabled: !dashboardCard.isUnavailable
            checked: dashboardCard.isOn
            Layout.alignment: Qt.AlignVCenter
            onToggled: {
                if (!dashboardCard.haManager || !dashboardCard.entityObj || dashboardCard.isUnavailable) return;
                dashboardCard.haManager.callService(dashboardCard.domain, checked ? "turn_on" : "turn_off", dashboardCard.cleanId, {});
            }
        }

        PlasmaComponents3.ToolButton {
            visible: dashboardCard.isLock
            icon.name: dashboardCard.isOn ? "object-unlocked-symbolic" : "object-locked-symbolic"
            enabled: !dashboardCard.isUnavailable
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                if (!dashboardCard.haManager || !dashboardCard.entityObj || dashboardCard.isUnavailable) return;
                dashboardCard.haManager.callService("lock", dashboardCard.isOn ? "lock" : "unlock", dashboardCard.cleanId, {});
            }
        }
    }
}
