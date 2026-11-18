import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: histSec
    required property var detailsPage
    required property var historyService

    Layout.fillWidth: true
    visible: historyService.events.length > 0
    radius: 10
    color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    border.width: 1
    implicitHeight: histCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: histCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.2
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "view-calendar"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: Kirigami.Theme.highlightColor
            }

            PlasmaComponents3.Label {
                text: Loc.t("RECENT HISTORY (72h)")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.86
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                visible: historyService.isLoading
                text: Loc.t("Loading…")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
            }
        }

        Repeater {
            model: historyService.events
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: modelData.timeStr
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.76
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: modelData.state
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.76
                    color: Kirigami.Theme.textColor
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
