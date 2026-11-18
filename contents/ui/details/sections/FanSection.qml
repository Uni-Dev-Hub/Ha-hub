import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: fanSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property int percentage: attrs.percentage !== undefined ? attrs.percentage : (detailsPage.isTurnedOn ? 100 : 0)

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: fanCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: fanCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("SPEED & MODES")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "view-refresh"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.highlightColor
            }
        }

        PlasmaComponents3.Label {
            text: detailsPage.isTurnedOn ? (fanSec.percentage + "% • " + Loc.t("On")) : Loc.t("Off")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: Kirigami.Theme.textColor
        }

        Controls.Slider {
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 1
            value: fanSec.percentage
            onMoved: {
                if (haManager) {
                    if (value > 0) {
                        haManager.callService("fan", "set_percentage", detailsPage.cleanId, { percentage: Math.round(value) });
                    } else {
                        haManager.callService("fan", "turn_off", detailsPage.cleanId, {});
                    }
                }
            }
        }

        RowLayout {
            visible: attrs.oscillating !== undefined
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: Loc.t("Oscillation mode"); Layout.fillWidth: true }
            PlasmaComponents3.Switch {
                checked: attrs.oscillating === true
                onToggled: {
                    if (haManager) haManager.callService("fan", "oscillate", detailsPage.cleanId, { oscillating: checked });
                }
            }
        }
    }
}
