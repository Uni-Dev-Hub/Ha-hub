import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../code/ha_helpers.js" as HAHelpers

Rectangle {
    id: swSec
    required property var detailsPage
    required property var haManager

    readonly property bool isOn: detailsPage.isTurnedOn

    Layout.fillWidth: true
    radius: 12
    color: swSec.isOn ? Qt.alpha(Kirigami.Theme.highlightColor, 0.08) : Qt.alpha(Kirigami.Theme.textColor, 0.03)
    border.color: swSec.isOn ? Qt.alpha(Kirigami.Theme.highlightColor, 0.28) : Qt.alpha(Kirigami.Theme.textColor, 0.08)
    border.width: 1
    implicitHeight: swCol.implicitHeight + Kirigami.Units.smallSpacing * 2.2

    ColumnLayout {
        id: swCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.4
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("SWITCH / RELAY")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: swSec.isOn ? "network-connect" : "network-disconnect"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: swSec.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            }
        }

        PlasmaComponents3.Label {
            text: swSec.isOn ? i18n("On") : i18n("Off")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.6
            color: swSec.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

        RowLayout {
            spacing: 5
            Rectangle {
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: swSec.isOn ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            }
            PlasmaComponents3.Label {
                text: {
                    var timeStr = HAHelpers.formatTimeInState(detailsPage.primaryEntityObj ? detailsPage.primaryEntityObj.last_changed : null);
                    return timeStr ? i18n("In this state for %1", timeStr) : i18n("Status is current");
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}
