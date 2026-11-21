pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../../code/mdi_icons.mjs" as MdiIcons
import "../mdi"

// One entity glyph, drawn from whichever source its name points at.
//
// Home Assistant stores icons as Material Design Icons names ("mdi:lamp-recessed")
// and the Plasma icon theme has no such names, so those are drawn straight from
// the bundled MDI font - that is what makes the tiles show the very icon the
// user picked in HA. A plain theme name (our domain fallback) still goes to
// Kirigami.Icon, and an MDI name the font does not carry - or a font that has
// not finished loading - falls back to it too.
Item {
    id: entityIcon
    objectName: "entityIcon"

    // "mdi" or "theme", as decided by HAHelpers.resolveEntityIcon().
    property string iconKind: "theme"
    // For "mdi" the bare name ("lightbulb"), for "theme" an icon theme name.
    property string icon: ""
    // Icon theme name to use when the MDI path does not work out.
    property string fallbackIcon: ""
    property real size: Kirigami.Units.iconSizes.smallMedium
    property color color: Kirigami.Theme.textColor

    readonly property string mdiFamily: MdiFont.family
    // Only draw a glyph when the font is really there; otherwise the private
    // use area codepoints would render as empty boxes.
    readonly property bool isMdi: iconKind === "mdi" && mdiFamily.length > 0
        && MdiIcons.mdiCodepoint(icon) !== 0
    readonly property string glyph: MdiIcons.mdiGlyph(icon)
    readonly property string themeSource: iconKind === "theme" && icon.length > 0
        ? icon
        : fallbackIcon

    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)

    // Exactly one painter is instantiated. Kirigami.Icon keeps the visibility
    // of the icon it could not load to itself, so a `visible: false` binding
    // on it would be quietly overridden - a Loader cannot draw twice.
    Loader {
        anchors.fill: parent
        sourceComponent: entityIcon.isMdi ? glyphComponent : themeComponent
    }

    Component {
        id: glyphComponent

        Text {
            objectName: "entityIconGlyph"
            anchors.fill: parent
            text: entityIcon.glyph
            font.family: entityIcon.mdiFamily
            // MDI glyphs are drawn on a 24px grid with a couple of pixels of
            // padding, so they are rendered slightly larger than the box to
            // end up the same visual size as the theme icons beside them.
            font.pixelSize: Math.round(entityIcon.size * 1.15)
            color: entityIcon.color
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Component {
        id: themeComponent

        Kirigami.Icon {
            objectName: "entityIconTheme"
            anchors.fill: parent
            source: entityIcon.themeSource
            color: entityIcon.color
        }
    }
}
