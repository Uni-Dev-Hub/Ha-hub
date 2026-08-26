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
        anchors.centerIn: parent
        source: compactRoot.isOnline ? "network-server-symbolic" : "network-offline"
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium
        opacity: compactRoot.isOnline ? 1.0 : 0.6
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: compactRoot.clicked()
    }
}
