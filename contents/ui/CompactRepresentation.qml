import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot

    property var haManager: null
    signal clicked()

    // Tray icon choice (Settings -> Appearance). Both empty means "follow the
    // connection status", which is also what the fallback modes resolve to.
    property string preferredIconName: ""
    property string preferredImagePath: ""

    readonly property bool isOnline: haManager && haManager.isConnected

    readonly property string imageSource: {
        if (compactRoot.preferredImagePath.length === 0) return "";
        var path = compactRoot.preferredImagePath;
        return path.indexOf("file:") === 0 ? path : "file://" + path;
    }

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
        objectName: "trayThemedIcon"
        anchors.centerIn: parent
        visible: compactRoot.imageSource.length === 0
        source: compactRoot.preferredIconName.length > 0
            ? compactRoot.preferredIconName
            : (compactRoot.isOnline ? "network-server-symbolic" : "network-offline")
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium
        opacity: compactRoot.isOnline ? 1.0 : 0.6
    }

    // Own picture: cannot be recolored by the theme, so the offline state is
    // shown by dimming it the same way.
    Image {
        id: pictureImage
        objectName: "trayPicture"
        anchors.centerIn: parent
        // Named so tests can observe the load state: under qmltestrunner no
        // item ever reports visible == true, so the flag has to be checked.
        readonly property bool loaded: status === Image.Ready
        visible: compactRoot.imageSource.length > 0 && loaded
        source: compactRoot.imageSource
        sourceSize.width: Kirigami.Units.iconSizes.smallMedium * 2
        sourceSize.height: Kirigami.Units.iconSizes.smallMedium * 2
        width: Kirigami.Units.iconSizes.smallMedium
        height: Kirigami.Units.iconSizes.smallMedium
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: compactRoot.isOnline ? 1.0 : 0.6
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: compactRoot.clicked()
    }
}
