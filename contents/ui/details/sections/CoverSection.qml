import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: coverSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property int position: attrs.current_position !== undefined ? attrs.current_position : (eObj && eObj.state === "open" ? 100 : 0)

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: coverCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: coverCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("POSITION & CONTROL")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "window"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.highlightColor
            }
        }

        PlasmaComponents3.Label {
            text: coverSec.position + "% • " + (eObj && eObj.state === "open" ? Loc.t("Open") : (eObj && eObj.state === "closed" ? Loc.t("Closed") : (eObj ? eObj.state : "—")))
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: Kirigami.Theme.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Open")
                icon.name: "arrow-up"
                onClicked: { if (haManager) haManager.callService("cover", "open_cover", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Stop")
                icon.name: "process-stop"
                onClicked: { if (haManager) haManager.callService("cover", "stop_cover", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Close")
                icon.name: "arrow-down"
                onClicked: { if (haManager) haManager.callService("cover", "close_cover", detailsPage.cleanId, {}); }
            }
        }

        Controls.Slider {
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 1
            value: coverSec.position
            onMoved: {
                if (haManager) haManager.callService("cover", "set_cover_position", detailsPage.cleanId, { position: Math.round(value) });
            }
        }
    }
}
