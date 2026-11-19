pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../code/dashboard_model.mjs" as DashboardModel
import "../../l10n"

// A flat Metro tile: the group colour fills the whole square, the entity icon
// and/or its name sit on top in a readable text colour. Tapping opens the
// entity details, exactly like the old cards did.
Item {
    id: metroTile
    objectName: "metroTile"

    property string entityId: ""
    property var haManager: null
    // Resolved colour of the owning group (accent already substituted).
    property color tileColor: Kirigami.Theme.highlightColor
    // "both" | "title" | "icon" - already resolved (tile override or default).
    property string contentMode: "both"
    // "small" | "medium" | "wide" | "large"
    property string size: "medium"

    signal openDetailsRequested(string entId)

    readonly property string cleanId: HAHelpers.cleanEntityId(entityId)
    readonly property var entityObj: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        return haManager ? haManager.getEntity(cleanId) : null;
    }
    readonly property var registryInfo: haManager && haManager.getEntityRegistry
        ? haManager.getEntityRegistry(cleanId) : null
    readonly property string domain: cleanId ? cleanId.split(".")[0] : ""
    readonly property string title: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        var entry = haManager && haManager.getCatalogEntry ? haManager.getCatalogEntry(cleanId) : null;
        if (entry && entry.name) return entry.name;
        return HAHelpers.getEntityTitle(cleanId, entityObj, registryInfo, haManager);
    }
    readonly property string statusText: HAHelpers.getStatusDetailsText(cleanId, entityObj,
        haManager && haManager.entityToDeviceMap ? (haManager.entityToDeviceMap[cleanId] || "") : "",
        haManager, Loc.language)
    readonly property string iconSource: {
        if (entityObj && entityObj.attributes && entityObj.attributes.icon) {
            return entityObj.attributes.icon;
        }
        if (registryInfo && registryInfo.icon) return registryInfo.icon;
        return HAHelpers.getDomainIcon(domain);
    }
    readonly property bool isUnavailable: !entityObj || entityObj.state === "unavailable" || entityObj.state === "unknown"
    // Small tiles are too tight for a label: they show the icon (or the name
    // when the tile is explicitly in title mode).
    readonly property bool compactTile: size === "small"
    readonly property bool showIcon: contentMode !== "title"
    readonly property bool showTitle: contentMode === "title" || (!compactTile && contentMode === "both")
    // Same rule as the dashboard model, applied here so a stray colour value
    // still produces legible text instead of invisible ink.
    readonly property color textColor: DashboardModel.readableTextColor(metroTile.colorToHex(tileColor))

    function colorToHex(c) {
        // QML color components are real numbers in 0..1.
        var hex = function (v) {
            var s = Math.round(v * 255).toString(16);
            return s.length < 2 ? "0" + s : s;
        };
        return "#" + hex(c.r) + hex(c.g) + hex(c.b);
    }

    implicitWidth: Kirigami.Units.gridUnit * 4
    implicitHeight: implicitWidth
    opacity: isUnavailable ? 0.45 : 1.0

    Rectangle {
        id: tileBg
        anchors.fill: parent
        // Metro tiles are flat: no radius, no border, no shadow.
        color: metroTile.tileColor
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (metroTile.cleanId) metroTile.openDetailsRequested(metroTile.cleanId);
        }
    }

    // Press feedback without breaking the flat look: the tile shrinks a bit.
    scale: tileMouse.pressed ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

    ColumnLayout {
        id: tileContent
        anchors.fill: parent
        anchors.margins: metroTile.compactTile ? 2 : Kirigami.Units.smallSpacing * 1.2
        spacing: 1
        opacity: tileMouse.containsMouse ? 0.9 : 1.0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // Icon sits centred above the text (classic tile placement).
        Item {
            visible: metroTile.showIcon
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.Icon {
                anchors.centerIn: parent
                source: metroTile.iconSource
                width: Math.max(Kirigami.Units.iconSizes.small,
                    Math.min(metroTile.width, metroTile.height) * (metroTile.compactTile ? 0.55 : 0.42))
                height: width
                color: metroTile.textColor
            }
        }

        // In title-only mode the text floats to the centre between the two
        // fillers instead of sticking to the bottom edge.
        Item {
            visible: !metroTile.showIcon
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        PlasmaComponents3.Label {
            visible: metroTile.showTitle
            text: metroTile.title
            color: metroTile.textColor
            elide: Text.ElideRight
            maximumLineCount: metroTile.size === "large" ? 2 : 1
            wrapMode: Text.WordWrap
            font.bold: true
            font.pointSize: metroTile.compactTile
                ? Kirigami.Theme.smallFont.pointSize * 0.85
                : (metroTile.size === "large"
                    ? Kirigami.Theme.defaultFont.pointSize * 1.2
                    : Kirigami.Theme.smallFont.pointSize)
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            visible: !metroTile.compactTile && metroTile.showTitle && metroTile.statusText.length > 0
            text: metroTile.isUnavailable ? Loc.t("Unavailable") : metroTile.statusText
            color: metroTile.textColor
            opacity: 0.85
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
            Layout.fillWidth: true
        }

        Item {
            visible: !metroTile.showIcon
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
