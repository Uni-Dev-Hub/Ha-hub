pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../components" as Components
import "../../code/dashboard_model.mjs" as DashboardModel
import "../../l10n"

ColumnLayout {
    id: dashboardRoot

    property var haManager: null
    // JSON of the configured tile groups; when empty the legacy v1.0 card
    // list (legacyCardsJson) is migrated into one untitled group on the fly.
    property string groupsJson: ""
    property string legacyCardsJson: ""
    // Number of 1x1 tile units across the grid.
    property int columns: 4
    // Global tile content default: "both" | "title" | "icon".
    property string tileContent: "both"

    signal configureRequested()
    signal openDetailsRequested(string entId)

    spacing: Kirigami.Units.smallSpacing

    readonly property var groups: {
        var all = DashboardModel.normalizeDashboardModel(groupsJson, legacyCardsJson);
        // A group with no tiles is a configuration leftover, not content.
        var visible = [];
        for (var i = 0; i < all.length; i++) {
            if (all[i].tiles.length > 0) visible.push(all[i]);
        }
        return visible;
    }

    Item {
        visible: dashboardRoot.groups.length === 0
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
                text: Loc.t("Create tile groups in Settings → Dashboard.")
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
        id: dashboardFlick
        visible: dashboardRoot.groups.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: groupsColumn.implicitHeight

        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            active: true
        }

        ColumnLayout {
            id: groupsColumn
            width: dashboardFlick.width
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: dashboardRoot.groups

                delegate: Components.DashboardGroup {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    group: modelData
                    haManager: dashboardRoot.haManager
                    columns: dashboardRoot.columns
                    defaultContent: dashboardRoot.tileContent
                    onOpenDetailsRequested: function(entId) {
                        dashboardRoot.openDetailsRequested(entId);
                    }
                }
            }
        }
    }
}
