import QtQuick
import org.kde.kirigami as Kirigami

// Rounded icon badge. Bundled SVGs are monochrome and drawn as a mask,
// so they always take the current Plasma theme colors.
Rectangle {
    id: badge

    property url source
    property bool active: false
    property bool unavailable: false
    property real iconSize: Kirigami.Units.iconSizes.small
    property bool circular: false
    property bool interactive: false
    // soft: translucent tint when active (glass cards) instead of a solid fill
    property bool soft: false
    signal clicked()

    implicitWidth: Math.round(iconSize * 1.9)
    implicitHeight: implicitWidth
    radius: circular ? width / 2 : Math.round(width * 0.3)

    color: {
        if (unavailable) return Qt.alpha(Kirigami.Theme.disabledTextColor, 0.10);
        if (active && soft) return Qt.alpha(Kirigami.Theme.highlightColor, iconMouse.containsMouse ? 0.36 : 0.24);
        if (active) return iconMouse.containsMouse ? Qt.lighter(Kirigami.Theme.highlightColor, 1.15) : Kirigami.Theme.highlightColor;
        return Qt.alpha(Kirigami.Theme.textColor, iconMouse.containsMouse ? 0.14 : 0.07);
    }
    border.width: 0
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: badge.iconSize
        height: badge.iconSize
        source: badge.source
        isMask: true
        color: badge.unavailable ? Kirigami.Theme.disabledTextColor
             : badge.active ? (badge.soft ? Kirigami.Theme.highlightColor : Kirigami.Theme.highlightedTextColor)
             : Kirigami.Theme.textColor
        opacity: badge.active || badge.unavailable ? 1.0 : 0.75
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        enabled: badge.interactive && !badge.unavailable
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: badge.clicked()
    }
}
