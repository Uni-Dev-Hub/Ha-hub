import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot

    property var haManager: null
    signal clicked()

    readonly property bool isOnline: haManager && haManager.isConnected

    readonly property real sideLength: {
        if (!parent) return Kirigami.Units.iconSizes.medium;
        var pWidth = parent.width > 0 ? parent.width : Kirigami.Units.iconSizes.medium;
        var pHeight = parent.height > 0 ? parent.height : Kirigami.Units.iconSizes.medium;
        return Math.min(pWidth, pHeight);
    }

    Layout.preferredWidth: sideLength
    Layout.preferredHeight: sideLength
    Layout.minimumWidth: Kirigami.Units.iconSizes.small
    Layout.minimumHeight: Kirigami.Units.iconSizes.small

    Kirigami.Icon {
        anchors.fill: parent
        anchors.margins: Math.round(compactRoot.sideLength * 0.12)
        source: Qt.resolvedUrl("../icons/home.svg")
        isMask: true
        color: Kirigami.Theme.textColor
        active: mouse.containsMouse
        opacity: compactRoot.isOnline ? 1.0 : 0.5
    }

    // Small red dot when disconnected
    Rectangle {
        visible: !compactRoot.isOnline
        width: Math.max(6, Math.round(compactRoot.sideLength * 0.25))
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(compactRoot.sideLength * 0.08)
        color: Kirigami.Theme.negativeTextColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: compactRoot.clicked()
    }
}
