import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: thermSec
    required property var detailsPage
    required property var haManager

    readonly property var eObj: detailsPage.primaryEntityObj
    readonly property var attrs: eObj && eObj.attributes ? eObj.attributes : ({})
    readonly property var hvacModes: attrs.hvac_modes || []
    readonly property var fanModes: attrs.fan_modes || []
    readonly property var swingModes: attrs.swing_modes || []
    readonly property var presetModes: attrs.preset_modes || []

    function getHvacName(m) {
        if (m === "heat") return Loc.t("Heating");
        if (m === "cool") return Loc.t("Cooling");
        if (m === "heat_cool" || m === "auto") return Loc.t("Auto");
        if (m === "dry") return Loc.t("Dry");
        if (m === "fan_only") return Loc.t("Fan only");
        if (m === "off") return Loc.t("Off");
        return m;
    }

    Layout.fillWidth: true
    radius: 12
    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
    border.width: 1
    implicitHeight: climateCol.implicitHeight + Kirigami.Units.smallSpacing * 2.5

    ColumnLayout {
        id: climateCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing * 1.2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: Loc.t("TEMPERATURE MODE"); font.bold: true; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75; color: Kirigami.Theme.disabledTextColor; Layout.fillWidth: true }
            Kirigami.Icon { source: "temperature-normal"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small; color: Kirigami.Theme.highlightColor }
        }

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                PlasmaComponents3.Label { text: Loc.t("Room Temperature"); font.pointSize: 8; color: Kirigami.Theme.disabledTextColor }
                PlasmaComponents3.Label {
                    text: attrs.current_temperature !== undefined ? (attrs.current_temperature + "°C") : "—"
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.6
                    color: Kirigami.Theme.textColor
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents3.ToolButton {
                    icon.name: "list-remove-symbolic"
                    onClicked: {
                        if (haManager && attrs.temperature !== undefined) {
                            haManager.callService("climate", "set_temperature", detailsPage.cleanId, { temperature: attrs.temperature - 0.5 });
                        }
                    }
                }
                PlasmaComponents3.Label {
                    text: attrs.temperature !== undefined ? (attrs.temperature + "°C") : "—"
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.3
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "list-add-symbolic"
                    onClicked: {
                        if (haManager && attrs.temperature !== undefined) {
                            haManager.callService("climate", "set_temperature", detailsPage.cleanId, { temperature: attrs.temperature + 0.5 });
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: thermSec.hvacModes.length > 0
            Layout.fillWidth: true
            spacing: 2

            PlasmaComponents3.Label { text: Loc.t("Operating Mode"); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82; color: Kirigami.Theme.disabledTextColor }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: thermSec.hvacModes
                    delegate: PlasmaComponents3.Button {
                        required property string modelData
                        text: thermSec.getHvacName(modelData)
                        highlighted: eObj && eObj.state === modelData
                        onClicked: {
                            if (haManager) haManager.callService("climate", "set_hvac_mode", detailsPage.cleanId, { hvac_mode: modelData });
                        }
                    }
                }
            }
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                visible: thermSec.fanModes.length > 0
                Layout.fillWidth: true
                spacing: 1
                PlasmaComponents3.Label { text: Loc.t("Fan Mode"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                PlasmaComponents3.ComboBox {
                    Layout.fillWidth: true
                    model: thermSec.fanModes
                    currentIndex: model ? model.indexOf(attrs.fan_mode) : 0
                    onActivated: {
                        if (haManager) haManager.callService("climate", "set_fan_mode", detailsPage.cleanId, { fan_mode: currentText });
                    }
                }
            }

            ColumnLayout {
                visible: thermSec.swingModes.length > 0
                Layout.fillWidth: true
                spacing: 1
                PlasmaComponents3.Label { text: Loc.t("Swing Mode"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                PlasmaComponents3.ComboBox {
                    Layout.fillWidth: true
                    model: thermSec.swingModes
                    currentIndex: model ? model.indexOf(attrs.swing_mode) : 0
                    onActivated: {
                        if (haManager) haManager.callService("climate", "set_swing_mode", detailsPage.cleanId, { swing_mode: currentText });
                    }
                }
            }
        }
    }
}
