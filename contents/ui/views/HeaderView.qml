import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: headerView

    property var fullRoot: null
    property var haManager: null

    signal configureRequested()
    signal toggleSearchRequested()
    signal viewModeSelected(string mode)

    readonly property bool connected: haManager && haManager.isConnected
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 15

    readonly property var viewModes: [
        { mode: "rows",  icon: "rows",  label: i18n("Rows") },
        { mode: "tiles", icon: "grid",  label: i18n("Tiles") },
        { mode: "cards", icon: "cards", label: i18n("Cards") }
    ]
    readonly property var currentMode: {
        var m = fullRoot ? fullRoot.viewMode : "rows";
        for (var i = 0; i < viewModes.length; i++) if (viewModes[i].mode === m) return viewModes[i];
        return viewModes[0];
    }

    implicitHeight: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Status dot with a soft halo; pulses while (re)connecting
        Item {
            implicitWidth: 14
            implicitHeight: 14
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: halo
                anchors.centerIn: parent
                width: 14; height: 14; radius: 7
                color: dot.color
                opacity: 0.25
                SequentialAnimation on opacity {
                    running: headerView.haManager && !headerView.connected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.05; duration: 700 }
                    NumberAnimation { to: 0.35; duration: 700 }
                    onRunningChanged: if (!running) halo.opacity = 0.25
                }
            }
            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: headerView.connected ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            PlasmaComponents3.Label {
                text: (haManager && haManager.serverName) ? haManager.serverName : "Home Assistant"
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: {
                    if (!haManager) return i18n("Disconnected");
                    if (!haManager.isConnected) return haManager.connectionStatus || i18n("Disconnected");
                    return i18np("%1 entity", "%1 entities", haManager.entityCount);
                }
                font: Kirigami.Theme.smallFont
                color: headerView.connected ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.negativeTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        PlasmaComponents3.ToolButton {
            visible: haManager && !headerView.connected
            icon.name: "view-refresh-symbolic"
            text: i18n("Reconnect")
            display: headerView.narrow ? PlasmaComponents3.AbstractButton.IconOnly : PlasmaComponents3.AbstractButton.TextBesideIcon
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered && headerView.narrow
            onClicked: haManager.reconnect()
        }

        PlasmaComponents3.ToolButton {
            visible: headerView.connected
            icon.source: Qt.resolvedUrl("../../icons/search.svg")
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: i18n("Search")
            checkable: true
            checked: fullRoot ? fullRoot.showSearchBar : false
            PlasmaComponents3.ToolTip.text: i18n("Search (Esc to close)")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: headerView.toggleSearchRequested()
        }

        PlasmaComponents3.ToolButton {
            id: viewButton
            visible: headerView.connected
            icon.source: Qt.resolvedUrl("../../icons/" + headerView.currentMode.icon + ".svg")
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: i18n("View: %1", headerView.currentMode.label)
            down: viewMenu.opened || pressed
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered && !viewMenu.opened
            onClicked: viewMenu.opened ? viewMenu.close() : viewMenu.popup(viewButton, 0, viewButton.height)

            PlasmaComponents3.Menu {
                id: viewMenu
                Repeater {
                    model: headerView.viewModes
                    delegate: PlasmaComponents3.MenuItem {
                        required property var modelData
                        text: modelData.label
                        icon.source: Qt.resolvedUrl("../../icons/" + modelData.icon + ".svg")
                        checkable: true
                        checked: headerView.currentMode.mode === modelData.mode
                        onTriggered: headerView.viewModeSelected(modelData.mode)
                    }
                }
            }
        }

        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: i18n("Settings")
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: headerView.configureRequested()
        }
    }
}
