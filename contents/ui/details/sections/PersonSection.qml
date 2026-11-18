import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: personSec
    required property var detailsPage

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property bool isHome: eObj && eObj.state === "home"

    Layout.fillWidth: true
    radius: 12
    color: personSec.isHome ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.10) : Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: personSec.isHome ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.35) : Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: personCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: personCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("PRESENCE STATUS")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "user-identity-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: personSec.isHome ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
            }
        }

        PlasmaComponents3.Label {
            text: personSec.isHome ? Loc.t("Home") : (eObj && eObj.state === "not_home" ? Loc.t("Away") : (eObj ? eObj.state : "—"))
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.6
            color: personSec.isHome ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
        }

        RowLayout {
            visible: attrs.latitude !== undefined && attrs.longitude !== undefined
            Layout.fillWidth: true
            PlasmaComponents3.Button {
                text: Loc.t("Open in Map")
                icon.name: "mark-location"
                onClicked: {
                    Qt.openUrlExternally("https://www.openstreetmap.org/?mlat=" + attrs.latitude + "&mlon=" + attrs.longitude + "#map=16/" + attrs.latitude + "/" + attrs.longitude);
                }
            }
        }
    }
}
