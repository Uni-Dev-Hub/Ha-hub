import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: sirenSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property bool isOn: eObj && eObj.state === "on"

    Layout.fillWidth: true
    radius: 12
    color: sirenSec.isOn ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.20) : Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: sirenSec.isOn ? Kirigami.Theme.negativeTextColor : Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1.5
    implicitHeight: sirenCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: sirenCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("ALARM SIREN")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "dialog-warning"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: sirenSec.isOn ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
            }
        }

        PlasmaComponents3.Label {
            text: sirenSec.isOn ? Loc.t("SIREN ACTIVE!") : Loc.t("Siren off")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: sirenSec.isOn ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            text: sirenSec.isOn ? Loc.t("Turn Off Siren") : Loc.t("Turn On Siren")
            icon.name: sirenSec.isOn ? "process-stop" : "dialog-warning"
            highlighted: true
            onClicked: {
                if (haManager) {
                    var srv = sirenSec.isOn ? "turn_off" : "turn_on";
                    haManager.callService("siren", srv, detailsPage.cleanId, {});
                }
            }
        }
    }
}
