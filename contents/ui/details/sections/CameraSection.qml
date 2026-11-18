import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: camSec
    required property var detailsPage
    required property var haManager

    property int refreshKey: 0

    readonly property string streamUrl: {
        if (!haManager || !detailsPage.cleanId) return "";
        var proto = haManager.useSsl ? "https://" : "http://";
        return proto + haManager.host + ":" + haManager.port + "/api/camera_proxy/" + detailsPage.cleanId + "?token=" + encodeURIComponent(haManager.accessToken) + "&_t=" + refreshKey;
    }

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: camCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: camCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("SURVEILLANCE CAMERA")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            PlasmaComponents3.ToolButton {
                icon.name: "view-refresh"
                onClicked: camSec.refreshKey = Date.now()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.round(width * 0.56)
            radius: 8
            clip: true
            color: "black"

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: camSec.streamUrl
                cache: false
            }
        }
    }
}
