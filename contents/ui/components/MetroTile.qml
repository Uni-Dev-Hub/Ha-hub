pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../code/dashboard_model.mjs" as DashboardModel
import "../../l10n"

// A compact single-row dashboard tile: deliberately a dumb presenter. Every
// entity-derived value (title, status, icon, value text, trailing kind and
// state pictogram, on/unavailable flags, action kind) is precomputed by the
// dashboard view's data controller and arrives through `presentation`, so a
// Home Assistant state storm never triggers helper calls from tile bindings -
// the tiles only read plain fields. Tap toggles/triggers the entity, long
// press opens the details, mirroring the switches the 1.0 cards offered.
//
// Visual concept (a device row, not a square): themed card, the entity glyph
// and the shortest honest answer to "how is it doing" along the top - a mini
// switch for lights/switches, a value for sensors ("21.5 °C", "54 %", "45%"),
// a pictogram for locks/covers/motion/media - and the entity name across the
// whole width along the bottom. Colour carries state: active entities glow in
// the group accent, inactive ones stay neutral grey, unavailable ones dim back
// behind a warning glyph.
Item {
    id: metroTile
    objectName: "metroTile"

    property string entityId: ""
    // Used only to send services from click handlers, never in bindings.
    property var haManager: null
    // Precomputed presentation from the view controller:
    // { title, status, icon, iconKind, fallbackIcon, valueText, trailing,
    //   stateIcon, domain, kind, isOn, unavailable } or null.
    // (Not called "data": that shadows QQuickItem's default property.)
    property var presentation: null
    // Accent of the owning group (resolved, "accent" already substituted):
    // it tints the tile content while the entity is active, never the fill.
    property color tileColor: Kirigami.Theme.highlightColor
    // "both" | "title" | "icon" - already resolved (tile override or default).
    property string contentMode: "both"
    // "small" | "medium" | "wide"
    property string size: "medium"

    signal openDetailsRequested(string entId)

    readonly property bool compactTile: size === "small"
    readonly property bool isIconMode: contentMode === "icon"
    readonly property bool showIcon: contentMode !== "title"
    readonly property bool showTitle: contentMode !== "icon"
    // A row only reserves room for the name when there is one to print.
    readonly property bool nameShown: showTitle && title.length > 0
    readonly property bool isOn: !!(presentation && presentation.isOn)
    readonly property bool isUnavailable: !presentation || !!presentation.unavailable
    readonly property string title: presentation && presentation.title ? presentation.title : ""
    readonly property string statusText: presentation && presentation.status ? presentation.status : ""
    readonly property string iconSource: presentation && presentation.icon ? presentation.icon : ""
    // "mdi" (name of a Material Design Icons glyph, as Home Assistant names
    // them) or "theme" (an icon theme name). See HAHelpers.resolveEntityIcon.
    readonly property string iconKind: presentation && presentation.iconKind ? presentation.iconKind : "theme"
    readonly property string fallbackIconSource: presentation && presentation.fallbackIcon
        ? presentation.fallbackIcon : "preferences-system-symbolic"
    readonly property string valueText: presentation && presentation.valueText ? presentation.valueText : ""
    readonly property string stateIcon: presentation && presentation.stateIcon ? presentation.stateIcon : ""
    // "switch" | "value" | "icon" - what answers on the right edge.
    readonly property string trailing: presentation ? (presentation.trailing || "icon") : "icon"

    readonly property bool active: isOn && !isUnavailable
    readonly property bool hovered: tileMouse.containsMouse
    readonly property string displayedStatus: isUnavailable ? Loc.t("Unavailable") : statusText
    readonly property bool showStatus: statusText.length > 0 || isUnavailable
    // Availability always wins over the normal trailing element.
    readonly property bool showSwitch: !isUnavailable && trailing === "switch"
    readonly property bool showValue: !isUnavailable && trailing === "value" && valueText.length > 0
    readonly property bool showTrailingIcon: isUnavailable
        || (trailing !== "switch" && trailing !== "value")
        || (trailing === "value" && valueText.length === 0)

    // The group accent tuned for the tile background: the hue is kept, only
    // the lightness moves when the raw colour would sink into the theme.
    readonly property color accent: metroTile.tunedAccent(metroTile.tileColor)
    readonly property color iconColor: metroTile.active ? metroTile.accent
        : Kirigami.Theme.disabledTextColor
    readonly property color valueColor: metroTile.active ? metroTile.accent
        : (metroTile.isUnavailable ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor)
    readonly property color titleColor: metroTile.active ? metroTile.accent
        : Kirigami.Theme.textColor

    // A row tile is short, so the type is deliberately small: the name takes at
    // most two light lines and sits at the bottom edge of the row, the value at
    // the end of the row is the same size without weight. Settings -> Dashboard
    // overrides both the size and the family there; an empty family means
    // whatever the theme picked, which is what a plain row has always used.
    readonly property real defaultPointSize: DashboardModel.TILE_POINT_SIZE_DEFAULT
    property real titlePointSize: metroTile.defaultPointSize
    property real valuePointSize: metroTile.defaultPointSize
    property string fontFamily: ""

    readonly property string effectiveFamily:
        fontFamily.length > 0 ? fontFamily : Kirigami.Theme.defaultFont.family

    function tunedAccent(c) {
        var darkBg = Kirigami.Theme.backgroundColor.hslLightness < 0.5;
        if (darkBg && c.hslLightness < 0.45)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.55, 1.0);
        if (!darkBg && c.hslLightness > 0.45)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.38, 1.0);
        return c;
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

    opacity: isUnavailable ? 0.55 : 1.0

    Rectangle {
        id: tileBg
        anchors.fill: parent
        radius: 8
        // Same visual family as the device cards: themed surface, hairline
        // border; the accent carries an active entity, hover brightens.
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: metroTile.active ? Qt.alpha(metroTile.accent, 0.55)
            : Qt.alpha(Kirigami.Theme.textColor, metroTile.hovered ? 0.20 : 0.12)
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Lifts the tile off the popup background and tints it while active.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: metroTile.active ? Qt.alpha(metroTile.accent, 0.10)
                : Qt.alpha(Kirigami.Theme.textColor, metroTile.hovered ? 0.08 : 0.05)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
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

    // Long names elide on the narrow rows; the tooltip hands back the full
    // name and the textual state the row itself no longer prints.
    PlasmaComponents3.ToolTip.text: metroTile.title
        + (metroTile.showStatus ? "\n" + metroTile.displayedStatus : "")
    PlasmaComponents3.ToolTip.visible: metroTile.hovered && metroTile.title.length > 0
    PlasmaComponents3.ToolTip.timeout: 5000

    // Press feedback without breaking the calm look: the tile shrinks a bit.
    scale: tileMouse.pressed ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

    // Two zones, so the name gets the whole width of the tile: the glyph and
    // the shortest honest answer to "how is it doing" share the top, the entity
    // name owns the bottom. With everything in one line, a one-column tile left
    // the name ~35 px after the glyph and the switch - enough for "Бол шо…" and
    // nothing else.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: metroTile.compactTile ? 4 : Kirigami.Units.smallSpacing * 0.9
        spacing: Kirigami.Units.smallSpacing * 0.4

        RowLayout {
            // Icon-mode tiles have no name to make room for, so the glyph may
            // take the whole tile instead of hugging the top edge.
            Layout.fillWidth: true
            Layout.fillHeight: !metroTile.nameShown
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.smallSpacing * 0.8

            // Entity glyph, drawn from Home Assistant's own icon: an mdi: name
            // is rendered from the bundled Material Design Icons font,
            // everything else through the icon theme. Small on purpose - the
            // name, not the glyph, is what a row is read by.
            EntityIcon {
                objectName: "tileGlyph"
                visible: metroTile.showIcon
                icon: metroTile.iconSource
                iconKind: metroTile.iconKind
                fallbackIcon: metroTile.fallbackIconSource
                size: metroTile.isIconMode
                    ? Kirigami.Units.iconSizes.medium
                    : Kirigami.Units.iconSizes.small
                color: metroTile.iconColor
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            }

            // The name lives below, so this is what keeps the answer at the
            // right edge of the row.
            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
            }

            // The switch on lights/switches tiles; the tile tap still toggles
            // too, the switch just shows the state honestly. Drawn smaller than
            // stock and wrapped in a plain Item: scale alone would reserve the
            // full unscaled size in the layout.
            Item {
                objectName: "tileTrailingSwitchSlot"
                visible: metroTile.showSwitch
                implicitWidth: tileSwitch.implicitWidth * tileSwitch.scale
                implicitHeight: tileSwitch.implicitHeight * tileSwitch.scale
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                PlasmaComponents3.Switch {
                    id: tileSwitch
                    objectName: "tileTrailingSwitch"
                    anchors.centerIn: parent
                    scale: 0.8
                    Binding on checked { value: metroTile.isOn }
                    onToggled: {
                        if (!metroTile.haManager || !metroTile.entityId || !metroTile.presentation) return;
                        var domain = metroTile.presentation.domain || "";
                        metroTile.haManager.callService(domain, checked ? "turn_on" : "turn_off",
                                                        metroTile.entityId, {});
                    }
                }
            }

            // Sensors speak in numbers.
            PlasmaComponents3.Label {
                objectName: "tileTrailingValue"
                visible: metroTile.showValue
                text: metroTile.valueText
                color: metroTile.valueColor
                font.bold: false
                font.family: metroTile.effectiveFamily
                font.pointSize: metroTile.valuePointSize
                elide: Text.ElideLeft
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            }

            // Everything else: one honest pictogram (lock, motion, play, warning).
            Kirigami.Icon {
                objectName: "tileTrailingIcon"
                visible: metroTile.showTrailingIcon
                source: metroTile.isUnavailable ? "dialog-warning-symbolic" : metroTile.stateIcon
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                color: metroTile.isUnavailable ? Kirigami.Theme.disabledTextColor : metroTile.iconColor
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            }
        }

        // The name: the full width of the tile, the bottom of the tile, and up
        // to two lines before the tooltip takes over with the whole text.
        PlasmaComponents3.Label {
            objectName: "tileTitle"
            visible: metroTile.nameShown
            text: metroTile.title
            color: metroTile.titleColor
            opacity: metroTile.active ? 1.0 : 0.9
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            lineHeight: 0.95
            lineHeightMode: Text.ProportionalHeight
            font.bold: false
            font.family: metroTile.effectiveFamily
            font.pointSize: metroTile.titlePointSize
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignBottom
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
        }
    }
}
