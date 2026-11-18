import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: valveSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property bool isOpen: eObj && eObj.state === "open"
    readonly property int position: attrs.current_position !== undefined ? attrs.current_position : (isOpen ? 100 : 0)

    Layout.fillWidth: true
    radius: 12
    color: valveSec.isOpen ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.10) : Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
    border.color: valveSec.isOpen ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.35) : Qt.alpha(Kirigami.Theme.negativeTextColor, 0.35)
    border.width: 1
    implicitHeight: valveCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: valveCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("SHUTOFF VALVE (WATER / GAS)")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
            Kirigami.Icon {
                source: "speedometer"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: valveSec.isOpen ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }
        }

        PlasmaComponents3.Label {
            text: valveSec.isOpen ? Loc.t("Valve open") : Loc.t("Fully closed")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.5
            color: valveSec.isOpen ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Open")
                icon.name: "arrow-up"
                highlighted: !valveSec.isOpen
                onClicked: { if (haManager) haManager.callService("valve", "open_valve", detailsPage.cleanId, {}); }
            }

            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: Loc.t("Close")
                icon.name: "dialog-error-symbolic"
                highlighted: valveSec.isOpen
                onClicked: { if (haManager) haManager.callService("valve", "close_valve", detailsPage.cleanId, {}); }
            }
        }

        Controls.Slider {
            visible: attrs.current_position !== undefined
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 1
            value: valveSec.position
            onMoved: {
                if (haManager) haManager.callService("valve", "set_valve_position", detailsPage.cleanId, { position: Math.round(value) });
            }
        }
    }
}
