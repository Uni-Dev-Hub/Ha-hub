import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../components" as Components

ColumnLayout {
    id: dashboardRoot

    property var haManager: null
    property string cardsJson: "[]"

    // Grid shape, bound from Plasmoid.configuration by FullRepresentation.
    property int columns: 2
    // "compact" or "normal": drives card chrome and which info rows show.
    property string cardSize: "compact"

    signal configureRequested()
    signal openDetailsRequested(string entId)

    spacing: Kirigami.Units.smallSpacing

    readonly property bool compact: cardSize !== "normal"

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

    // Card height for the base grid row; spanning cards double it.
    readonly property real rowHeight: (compact ? Kirigami.Units.gridUnit * 3.4 : Kirigami.Units.gridUnit * 4.6) + Kirigami.Units.smallSpacing

    function sizeOf(modelData) {
        var s = (modelData && modelData.size) || "1x1";
        return s === "2x1" || s === "1x2" || s === "2x2" ? s : "1x1";
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
                text: Loc.t("Dashboard is empty")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.1
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: Loc.t("Add cards in Settings → Dashboard.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                text: Loc.t("Open Settings")
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
            columns: Math.max(1, dashboardRoot.columns)
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: dashboardRoot.cards

                delegate: Components.DashboardCard {
                    required property var modelData
                    required property int index

                    readonly property string cardSizeKind: dashboardRoot.sizeOf(modelData)
                    readonly property bool wide: cardSizeKind === "2x1" || cardSizeKind === "2x2"
                    readonly property bool tall: cardSizeKind === "1x2" || cardSizeKind === "2x2"

                    Layout.fillWidth: true
                    Layout.columnSpan: wide ? Math.min(2, Math.max(1, dashboardRoot.columns)) : 1
                    Layout.rowSpan: tall ? 2 : 1
                    Layout.preferredHeight: tall
                        ? dashboardRoot.rowHeight * 2 + grid.rowSpacing
                        : dashboardRoot.rowHeight

                    entityId: modelData.entityId || ""
                    haManager: dashboardRoot.haManager
                    compact: dashboardRoot.compact
                    showArea: !dashboardRoot.compact || wide
                    showTime: !dashboardRoot.compact || tall

                    onOpenDetailsRequested: function(entId) {
                        dashboardRoot.openDetailsRequested(entId);
                    }
                    onConfigureRequested: dashboardRoot.configureRequested()
                }
            }
        }
    }
}
