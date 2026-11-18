import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../components" as Components

ColumnLayout {
    id: dashboardRoot

    property var haManager: null
    property string cardsJson: "[]"

    signal configureRequested()
    signal openDetailsRequested(string entId)

    spacing: Kirigami.Units.smallSpacing

    readonly property var cards: {
        var raw = dashboardRoot.cardsJson ? dashboardRoot.cardsJson.trim() : "";
        if (!raw) return [];
        try {
            var parsed = JSON.parse(raw);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    Item {
        visible: dashboardRoot.cards.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.86
            spacing: Kirigami.Units.mediumSpacing

            Kirigami.Icon {
                source: "view-grid-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                text: i18n("Dashboard is empty")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.1
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: i18n("Add cards in Settings → Dashboard.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                text: i18n("Open Settings")
                icon.name: "configure"
                highlighted: true
                Layout.alignment: Qt.AlignHCenter
                onClicked: dashboardRoot.configureRequested()
            }
        }
    }

    Flickable {
        visible: dashboardRoot.cards.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: grid.implicitHeight

        GridLayout {
            id: grid
            width: parent.width
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: dashboardRoot.cards

                delegate: Components.DashboardCard {
                    required property var modelData
                    required property int index

                    readonly property bool wide: (modelData.size || "") === "2x1" || (modelData.size || "") === "2x2"
                    readonly property bool tall: (modelData.size || "") === "2x2"

                    Layout.fillWidth: true
                    Layout.columnSpan: wide ? 2 : 1
                    Layout.rowSpan: tall ? 2 : 1
                    Layout.preferredHeight: tall
                        ? Kirigami.Units.gridUnit * 9
                        : Kirigami.Units.gridUnit * 5.5

                    entityId: modelData.entityId || ""
                    haManager: dashboardRoot.haManager

                    onOpenDetailsRequested: function(entId) {
                        dashboardRoot.openDetailsRequested(entId);
                    }
                    onConfigureRequested: dashboardRoot.configureRequested()
                }
            }
        }
    }
}
