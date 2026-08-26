import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Rectangle {
    id: genSec
    required property var detailsPage

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: genericCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: genericCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label { text: i18n("CURRENT STATE"); font.bold: true; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75; color: Kirigami.Theme.disabledTextColor }

        PlasmaComponents3.Label {
            text: {
                if (!detailsPage.primaryEntityObj) return i18n("Unavailable");
                var st = detailsPage.primaryEntityObj.state;
                var u = (detailsPage.primaryEntityObj.attributes && detailsPage.primaryEntityObj.attributes.unit_of_measurement) ? (" " + detailsPage.primaryEntityObj.attributes.unit_of_measurement) : "";
                return st + u;
            }
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: Kirigami.Theme.textColor
        }
    }
}
