pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/dashboard_model.mjs" as DashboardModel

// One Metro group: an optional header line and the tile grid below it. The
// grid is placed by hand from the pure layoutTiles() packing, so tile
// geometry derives only from the group width and never feeds back into it -
// the width feedback loop a GridLayout with sized children used to create
// made the tiles grow without bound.
Item {
    id: groupRoot
    objectName: "dashboardGroup"

    property var group: null
    property var haManager: null
    // entityId -> precomputed presentation object from the view controller.
    property var dataMap: ({})
    property int columns: 4
    // Global default for tiles without their own override.
    property string defaultContent: "both"

    signal openDetailsRequested(string entId)

    readonly property real tileSpacing: Kirigami.Units.smallSpacing * 0.9
    // Width of one 1x1 grid unit for the current popup width; the single
    // source of geometry, computed top-down and only from the width.
    readonly property real unit: columns > 0
        ? Math.max(0, (groupRoot.width - tileSpacing * (groupRoot.columns - 1)) / groupRoot.columns)
        : 0
    readonly property string groupColor: group && group.color
        ? group.color : String(Kirigami.Theme.highlightColor)
    readonly property var tileList: group && group.tiles ? group.tiles : []
    readonly property var placement: groupRoot.unit > 0
        ? DashboardModel.layoutTiles(groupRoot.tileList, groupRoot.columns,
                                     groupRoot.unit, groupRoot.tileSpacing)
        : { rects: [], height: 0 }
    readonly property real headerHeight: nameLabel.visible
        ? nameLabel.implicitHeight + Kirigami.Units.smallSpacing * 0.6
        : 0

    implicitWidth: groupRoot.width
    implicitHeight: groupRoot.headerHeight + gridHost.height

    PlasmaComponents3.Label {
        id: nameLabel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: text.length > 0
        text: groupRoot.group ? (groupRoot.group.name || "") : ""
        font.bold: true
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        color: Kirigami.Theme.disabledTextColor
        elide: Text.ElideRight
    }

    Item {
        id: gridHost
        objectName: "metroGrid"
        anchors.top: nameLabel.visible ? nameLabel.bottom : parent.top
        anchors.topMargin: nameLabel.visible ? Kirigami.Units.smallSpacing * 0.6 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: groupRoot.placement.height

        Repeater {
            // Not Array.isArray(): modules run in their own JS realm in QML,
            // so module-returned arrays answer false there. Duck-type instead.
            model: groupRoot.tileList

            delegate: MetroTile {
                id: tileDelegate
                required property var modelData
                required property int index

                // One rect per tile in input order; a missing rect (foreign
                // realm hiccup) keeps the tile visible instead of crashing.
                readonly property var rect: groupRoot.placement.rects[index]
                    ? groupRoot.placement.rects[index] : ({ x: 0, y: 0, w: 0, h: 0 })

                x: rect.x
                y: rect.y
                width: rect.w
                height: rect.h

                entityId: modelData.entityId || ""
                haManager: groupRoot.haManager
                presentation: groupRoot.dataMap ? groupRoot.dataMap[entityId] : null
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
