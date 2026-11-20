pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/dashboard_model.mjs" as DashboardModel
import "../../l10n"

// A flat Metro tile: deliberately a dumb presenter. Every entity-derived value
// (title, status, icon, on/unavailable flags, action kind) is precomputed by
// the dashboard view's data controller and arrives through `presentation`,
// so a Home Assistant state storm never triggers helper calls from tile
// bindings - the tiles only read plain fields. Tap toggles/triggers the
// entity, long press
// opens the details, mirroring the switches the 1.0 cards offered.
Item {
    id: metroTile
    objectName: "metroTile"

    property string entityId: ""
    // Used only to send services from click handlers, never in bindings.
    property var haManager: null
    // Precomputed presentation from the view controller:
    // { title, status, icon, domain, kind, isOn, unavailable } or null.
    // (Not called "data": that shadows QQuickItem's default property.)
    property var presentation: null
    // Resolved colour of the owning group (accent already substituted).
    property color tileColor: Kirigami.Theme.highlightColor
    // "both" | "title" | "icon" - already resolved (tile override or default).
    property string contentMode: "both"
    // "small" | "medium" | "wide" | "large"
    property string size: "medium"

    signal openDetailsRequested(string entId)

    // Small tiles are too tight for a label: they show the icon (or the name
    // when the tile is explicitly in title mode).
    readonly property bool compactTile: size === "small"
    readonly property bool showIcon: contentMode !== "title"
    readonly property bool showTitle: contentMode === "title" || (!compactTile && contentMode === "both")
    readonly property bool isOn: !!(presentation && presentation.isOn)
    readonly property bool isUnavailable: !presentation || !!presentation.unavailable
    readonly property string title: presentation && presentation.title ? presentation.title : ""
    readonly property string statusText: presentation && presentation.status ? presentation.status : ""
    readonly property string iconSource: presentation && presentation.icon ? presentation.icon : ""
    // Same rule as the dashboard model, but the binding only re-evaluates on
    // a colour change - never on entity state changes.
    readonly property color textColor: DashboardModel.readableTextColor(metroTile.colorToHex(tileColor))

    function colorToHex(c) {
        // QML color components are real numbers in 0..1.
        var hex = function (v) {
            var s = Math.round(v * 255).toString(16);
            return s.length < 2 ? "0" + s : s;
        };
        return "#" + hex(c.r) + hex(c.g) + hex(c.b);
    }

    // Tap: the direct action the old card switches provided. Non-controllable
    // entities fall through to their details page.
    function activate() {
        if (!haManager || !entityId || !presentation || presentation.unavailable) return;
        var kind = presentation.kind || "view";
        var domain = presentation.domain || "";
        if (kind === "toggle") {
            haManager.callService(domain, isOn ? "turn_off" : "turn_on", entityId, {});
        } else if (kind === "lock") {
            // isOn means "unlocked" here, exactly like on the device cards.
            haManager.callService("lock", isOn ? "lock" : "unlock", entityId, {});
        } else if (kind === "action") {
            if (domain === "script") haManager.callService("script", entityId.split(".")[1], entityId, {});
            else if (domain === "scene") haManager.callService("scene", "turn_on", entityId, {});
            else if (domain === "automation") haManager.callService("automation", "trigger", entityId, {});
            else if (domain === "button") haManager.callService("button", "press", entityId, {});
            else if (domain === "input_button") haManager.callService("input_button", "press", entityId, {});
        } else {
            metroTile.openDetailsRequested(entityId);
        }
    }

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
        onClicked: metroTile.activate()
        onPressAndHold: {
            if (metroTile.entityId) metroTile.openDetailsRequested(metroTile.entityId);
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
