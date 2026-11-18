import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: weatherSec
    required property var detailsPage

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: wCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: wCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("WEATHER CONDITIONS")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "weather-clouds"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.highlightColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: (attrs.temperature !== undefined ? (attrs.temperature + "°C") : "—") + " • " + (eObj ? eObj.state : "")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.6
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                visible: attrs.humidity !== undefined
                text: Loc.t("Humidity: %1%", attrs.humidity)
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                visible: attrs.wind_speed !== undefined
                text: Loc.t("Wind: %1 km/h", attrs.wind_speed)
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}
