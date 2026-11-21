pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

PlasmaComponents3.ToolBar {
    id: headerView

    property var fullRoot: null
    property var haManager: null
    // Optional single entity shown next to the greeting (e.g. a temperature
    // sensor) and whether its name is printed in front of the value.
    property string headerEntityId: ""
    property bool headerEntityLabel: false

    signal configureRequested()

    implicitHeight: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

    readonly property bool connected: haManager && haManager.isConnected

    readonly property string pictureUrl: connected ? (haManager.primaryPersonPictureUrl || "") : ""

    readonly property string headerEntityText: {
        if (!connected || headerView.headerEntityId.length === 0) return "";
        var rev = haManager.entitiesRevision;
        return HAHelpers.getEntityHeaderValue(headerView.headerEntityId,
            haManager.getEntity(HAHelpers.cleanEntityId(headerView.headerEntityId)),
            haManager, Loc.language, headerView.headerEntityLabel);
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        // User picture from Home Assistant through Kirigami.Avatar: a true
        // circular photo (a ShadowedRectangle "mask" painted a solid circle
        // over the image), with the user's initials as the fallback when the
        // account has no avatar and an icon when there is not even a name.
        Kirigami.Avatar {
            id: avatarImage
            readonly property real side: Math.round(Kirigami.Units.iconSizes.small * 1.7)
            implicitWidth: side
            implicitHeight: side
            Layout.alignment: Qt.AlignVCenter
            name: headerView.haManager ? (headerView.haManager.primaryPersonName || "") : ""
            source: headerView.pictureUrl
            sourceSize.width: side * 2
            sourceSize.height: side * 2
            cache: true
            icon.name: headerView.connected ? "user-identity-symbolic" : "network-offline"
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: headerView.connected && headerView.fullRoot ? headerView.fullRoot.greetingText : "Home Assistant"
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 0.95
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    visible: headerView.headerEntityText.length > 0
                    text: headerView.headerEntityText
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 0.95
                    color: Kirigami.Theme.highlightColor
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            PlasmaComponents3.Label {
                text: {
                    if (!headerView.haManager) return Loc.t("Disconnected");
                    if (!headerView.connected) return headerView.haManager.connectionStatus;
                    return headerView.haManager.serverName + " • " + Loc.t("Connected");
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: headerView.connected ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            PlasmaComponents3.ToolTip.visible: hovered
            PlasmaComponents3.ToolTip.text: Loc.t("Settings")
            onClicked: headerView.configureRequested()
        }
    }
}
