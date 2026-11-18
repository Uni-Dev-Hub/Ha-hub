import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: alarmSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property string rawState: eObj ? eObj.state : "disarmed"
    readonly property bool isArmed: rawState.startsWith("armed")
    readonly property bool isTriggered: rawState === "triggered"

    Layout.fillWidth: true
    radius: 12
    color: alarmSec.isTriggered ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.20) : (alarmSec.isArmed ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12) : Qt.alpha(Kirigami.Theme.positiveTextColor, 0.10))
    border.color: alarmSec.isTriggered ? Kirigami.Theme.negativeTextColor : (alarmSec.isArmed ? Kirigami.Theme.highlightColor : Kirigami.Theme.positiveTextColor)
    border.width: 1.5
    implicitHeight: alarmCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: alarmCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("SECURITY & ALARM SYSTEM")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "security-high-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: alarmSec.isTriggered ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
            }
        }

        PlasmaComponents3.Label {
            text: {
                if (alarmSec.isTriggered) return Loc.t("ALARM TRIGGERED!");
                if (alarmSec.rawState === "armed_home") return Loc.t("Armed Home");
                if (alarmSec.rawState === "armed_away") return Loc.t("Armed Away");
                if (alarmSec.rawState === "armed_night") return Loc.t("Armed Night");
                if (alarmSec.rawState === "pending") return Loc.t("Arming delay...");
                return Loc.t("Disarmed");
            }
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.45
            color: alarmSec.isTriggered ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Home")
                icon.name: "go-home"
                highlighted: alarmSec.rawState === "armed_home"
                onClicked: { if (haManager) haManager.callService("alarm_control_panel", "alarm_arm_home", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Away")
                icon.name: "system-lock-screen"
                highlighted: alarmSec.rawState === "armed_away"
                onClicked: { if (haManager) haManager.callService("alarm_control_panel", "alarm_arm_away", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Night")
                icon.name: "weather-clear-night"
                highlighted: alarmSec.rawState === "armed_night"
                onClicked: { if (haManager) haManager.callService("alarm_control_panel", "alarm_arm_night", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Disarm")
                icon.name: "object-unlocked-symbolic"
                highlighted: alarmSec.rawState === "disarmed"
                onClicked: { if (haManager) haManager.callService("alarm_control_panel", "alarm_disarm", detailsPage.cleanId, {}); }
            }
        }
    }
}
