import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "../../l10n"

PlasmaComponents3.ToolBar {
    id: headerView

    property var fullRoot: null
    property var haManager: null

    signal configureRequested()

    implicitHeight: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        Kirigami.Icon {
            source: haManager && haManager.isConnected ? "user-identity-symbolic" : "network-offline"
            implicitWidth: Kirigami.Units.iconSizes.small * 1.1
            implicitHeight: Kirigami.Units.iconSizes.small * 1.1
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: haManager && haManager.isConnected ? fullRoot.greetingText : "Home Assistant"
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 0.95
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: betaLabel.implicitWidth + 8
                    implicitHeight: betaLabel.implicitHeight + 2
                    radius: 4
                    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.45)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents3.ToolTip.visible: betaMouseArea.containsMouse
                    PlasmaComponents3.ToolTip.text: Loc.t("HA-Hub v1.0-beta1 (Public Beta)")

                    MouseArea {
                        id: betaMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    PlasmaComponents3.Label {
                        id: betaLabel
                        anchors.centerIn: parent
                        text: "BETA 1"
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.70
                        color: Kirigami.Theme.highlightColor
                    }
                }
            }

            PlasmaComponents3.Label {
                text: {
                    if (!haManager) return Loc.t("Disconnected");
                    if (!haManager.isConnected) return haManager.connectionStatus;
                    return haManager.serverName + " • " + Loc.t("Connected");
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: (haManager && haManager.isConnected) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
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
