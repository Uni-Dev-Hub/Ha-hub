import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: vacSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property string rawState: eObj ? eObj.state : "docked"
    readonly property int battery: attrs.battery_level !== undefined ? attrs.battery_level : -1

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: vacCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: vacCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("CLEANING STATUS")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                visible: vacSec.battery >= 0
                text: vacSec.battery + "%"
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: Kirigami.Theme.textColor
            }
        }

        PlasmaComponents3.Label {
            text: {
                if (vacSec.rawState === "cleaning") return Loc.t("Cleaning...");
                if (vacSec.rawState === "docked") return Loc.t("Docked");
                if (vacSec.rawState === "returning") return Loc.t("Returning to dock");
                if (vacSec.rawState === "paused") return Loc.t("Paused");
                if (vacSec.rawState === "error") return Loc.t("Vacuum error!");
                return vacSec.rawState;
            }
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: Kirigami.Theme.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: vacSec.rawState === "cleaning" ? Loc.t("Pause") : Loc.t("Clean")
                icon.name: vacSec.rawState === "cleaning" ? "media-playback-pause" : "media-playback-start"
                highlighted: vacSec.rawState === "cleaning"
                onClicked: {
                    if (!haManager) return;
                    if (vacSec.rawState === "cleaning") haManager.callService("vacuum", "pause", detailsPage.cleanId, {});
                    else haManager.callService("vacuum", "start", detailsPage.cleanId, {});
                }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Dock")
                icon.name: "go-home"
                onClicked: { if (haManager) haManager.callService("vacuum", "return_to_base", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.ToolButton {
                icon.name: "audio-volume-high"
                PlasmaComponents3.ToolTip.visible: hovered
                PlasmaComponents3.ToolTip.text: Loc.t("Locate vacuum (sound)")
                onClicked: { if (haManager) haManager.callService("vacuum", "locate", detailsPage.cleanId, {}); }
            }
        }
    }
}
