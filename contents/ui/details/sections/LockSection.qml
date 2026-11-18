import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: lockSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property bool isLocked: eObj ? (eObj.state === "locked") : false

    Layout.fillWidth: true
    radius: 12
    color: lockSec.isLocked ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.10) : Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
    border.color: lockSec.isLocked ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.35) : Qt.alpha(Kirigami.Theme.negativeTextColor, 0.35)
    border.width: 1
    implicitHeight: lockCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: lockCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("SMART LOCK")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: lockSec.isLocked ? "object-locked-symbolic" : "object-unlocked-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: lockSec.isLocked ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }
        }

        PlasmaComponents3.Label {
            text: lockSec.isLocked ? Loc.t("Locked") : Loc.t("Unlocked")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.6
            color: lockSec.isLocked ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            text: lockSec.isLocked ? Loc.t("Unlock") : Loc.t("Lock")
            icon.name: lockSec.isLocked ? "object-unlocked-symbolic" : "object-locked-symbolic"
            highlighted: !lockSec.isLocked
            onClicked: {
                if (haManager) {
                    var srv = lockSec.isLocked ? "unlock" : "lock";
                    haManager.callService("lock", srv, detailsPage.cleanId, {});
                }
            }
        }
    }
}
