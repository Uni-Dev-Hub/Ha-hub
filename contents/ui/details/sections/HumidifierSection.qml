import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: humSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property int targetHumidity: attrs.humidity !== undefined ? attrs.humidity : 50

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: humCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: humCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("HUMIDIFICATION")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "speedometer"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.highlightColor
            }
        }

        PlasmaComponents3.Label {
            text: detailsPage.isTurnedOn ? (Loc.t("Target humidity: ") + humSec.targetHumidity + "%") : Loc.t("Off")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: Kirigami.Theme.textColor
        }

        Controls.Slider {
            Layout.fillWidth: true
            from: 20
            to: 80
            stepSize: 1
            value: humSec.targetHumidity
            onMoved: {
                if (haManager) haManager.callService("humidifier", "set_humidity", detailsPage.cleanId, { humidity: Math.round(value) });
            }
        }
    }
}
