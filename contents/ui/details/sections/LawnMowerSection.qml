import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: mowerSec
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
    implicitHeight: mowerCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: mowerCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("ROBOTIC LAWN MOWER")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                visible: mowerSec.battery >= 0
                text: mowerSec.battery + "%"
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: Kirigami.Theme.textColor
            }
        }

        PlasmaComponents3.Label {
            text: {
                if (mowerSec.rawState === "mowing") return Loc.t("Mowing lawn...");
                if (mowerSec.rawState === "docked") return Loc.t("Docked");
                if (mowerSec.rawState === "paused") return Loc.t("Paused");
                if (mowerSec.rawState === "error") return Loc.t("Mower error!");
                return mowerSec.rawState;
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
                text: mowerSec.rawState === "mowing" ? Loc.t("Pause") : Loc.t("Mow")
                icon.name: mowerSec.rawState === "mowing" ? "media-playback-pause" : "media-playback-start"
                highlighted: mowerSec.rawState === "mowing"
                onClicked: {
                    if (!haManager) return;
                    if (mowerSec.rawState === "mowing") haManager.callService("lawn_mower", "pause", detailsPage.cleanId, {});
                    else haManager.callService("lawn_mower", "start_mowing", detailsPage.cleanId, {});
                }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Dock")
                icon.name: "go-home"
                onClicked: { if (haManager) haManager.callService("lawn_mower", "dock", detailsPage.cleanId, {}); }
            }
        }
    }
}
