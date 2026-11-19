pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/dashboard_model.mjs" as DashboardModel

// One Metro group: an optional header line and the tile grid below it. The
// grid is built from square units so the Metro proportions (wide = 2x1
// units and so on) always hold, no matter how wide the popup is.
ColumnLayout {
    id: groupRoot
    objectName: "dashboardGroup"

    property var group: null
    property var haManager: null
    property int columns: 4
    // Global default for tiles without their own override.
    property string defaultContent: "both"

    signal openDetailsRequested(string entId)

    readonly property real tileSpacing: Kirigami.Units.smallSpacing * 0.9
    // Width of one 1x1 grid unit for the current popup width.
    readonly property real unit: {
        var cols = Math.max(1, groupRoot.columns);
        var avail = groupRoot.width - tileSpacing * (cols - 1);
        return cols > 0 && avail > 0 ? avail / cols : 0;
    }
    readonly property string groupColor: group && group.color
        ? group.color : String(Kirigami.Theme.highlightColor)

    spacing: groupRoot.tileSpacing

    PlasmaComponents3.Label {
        visible: !!groupRoot.group && (groupRoot.group.name || "").length > 0
        text: groupRoot.group ? (groupRoot.group.name || "") : ""
        font.bold: true
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        color: Kirigami.Theme.disabledTextColor
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    GridLayout {
        id: tileGrid
        Layout.fillWidth: true
        columns: Math.max(1, groupRoot.columns)
        columnSpacing: groupRoot.tileSpacing
        rowSpacing: groupRoot.tileSpacing

        Repeater {
            // Not Array.isArray(): modules run in their own JS realm in QML,
            // so module-returned arrays answer false there. Duck-type instead.
            model: groupRoot.group && groupRoot.group.tiles
                ? groupRoot.group.tiles : []

            delegate: MetroTile {
                id: tileDelegate
                required property var modelData
                required property int index

                readonly property var span: DashboardModel.tileSpan(modelData.size, groupRoot.columns)

                Layout.preferredWidth: span.cols * groupRoot.unit
                    + (span.cols - 1) * groupRoot.tileSpacing
                Layout.preferredHeight: span.rows * groupRoot.unit
                    + (span.rows - 1) * groupRoot.tileSpacing

                entityId: modelData.entityId || ""
                haManager: groupRoot.haManager
                size: modelData.size || "medium"
                tileColor: groupRoot.groupColor
                contentMode: modelData.content && modelData.content.length > 0
                    ? modelData.content : groupRoot.defaultContent
                onOpenDetailsRequested: function(entId) {
                    groupRoot.openDetailsRequested(entId);
                }
            }
        }
    }
}
