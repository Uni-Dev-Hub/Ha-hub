import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: whSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: whCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: whCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: Loc.t("WATER HEATER")
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

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                PlasmaComponents3.Label { text: Loc.t("Current Temperature"); font.pointSize: 8; color: Kirigami.Theme.disabledTextColor }
                PlasmaComponents3.Label {
                    text: attrs.current_temperature !== undefined ? (attrs.current_temperature + "°C") : "—"
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.5
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents3.ToolButton {
                    icon.name: "list-remove-symbolic"
                    onClicked: {
                        if (haManager && attrs.temperature !== undefined) {
                            haManager.callService("water_heater", "set_temperature", detailsPage.cleanId, { temperature: attrs.temperature - 1 });
                        }
                    }
                }
                PlasmaComponents3.Label {
                    text: attrs.temperature !== undefined ? (attrs.temperature + "°C") : "—"
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.2
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "list-add-symbolic"
                    onClicked: {
                        if (haManager && attrs.temperature !== undefined) {
                            haManager.callService("water_heater", "set_temperature", detailsPage.cleanId, { temperature: attrs.temperature + 1 });
                        }
                    }
                }
            }
        }

        PlasmaComponents3.ComboBox {
            visible: attrs.operation_list !== undefined && attrs.operation_list.length > 0
            Layout.fillWidth: true
            model: attrs.operation_list || []
            currentIndex: model ? model.indexOf(attrs.operation_mode) : 0
            onActivated: {
                if (haManager) haManager.callService("water_heater", "set_operation_mode", detailsPage.cleanId, { operation_mode: currentText });
            }
        }
    }
}
