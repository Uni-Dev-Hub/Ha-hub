import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

Rectangle {
    id: optSec
    required property var detailsPage
    required property var haManager

    Layout.fillWidth: true
    radius: 10
    color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    implicitHeight: optionsCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: optionsCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.2
        spacing: 0

        Item {
            Layout.fillWidth: true
            implicitHeight: optHeaderRow.implicitHeight + Kirigami.Units.smallSpacing

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: detailsPage.optionsExpanded = !detailsPage.optionsExpanded
            }

            RowLayout {
                id: optHeaderRow
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon { source: "configure"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small; color: Kirigami.Theme.disabledTextColor }
                PlasmaComponents3.Label {
                    text: Loc.t("Parameters & Options (%1)", detailsPage.configEntitiesList.length)
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.88
                    Layout.fillWidth: true
                }
                Kirigami.Icon {
                    source: detailsPage.optionsExpanded ? "arrow-down" : "arrow-right"
                    implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }

        ColumnLayout {
            visible: detailsPage.optionsExpanded
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing

            Repeater {
                model: detailsPage.configEntitiesList
                delegate: Rectangle {
                    required property string modelData
                    readonly property var eObj: haManager ? haManager.getEntity(modelData) : null
                    readonly property string eDom: modelData.split(".")[0]

                    Layout.fillWidth: true
                    radius: 6
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
                    implicitHeight: cfgItemRow.implicitHeight + Kirigami.Units.smallSpacing * 1.2

                    RowLayout {
                        id: cfgItemRow
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: (eObj && eObj.attributes && eObj.attributes.friendly_name) ? eObj.attributes.friendly_name : modelData
                                font.bold: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label { text: modelData; font.pointSize: 7; color: Kirigami.Theme.disabledTextColor; elide: Text.ElideRight }
                        }

                        PlasmaComponents3.Button {
                            visible: eDom === "button" || eDom === "input_button" || eDom === "update"
                            text: eDom === "update" ? Loc.t("Install") : Loc.t("Execute")
                            icon.name: eDom === "update" ? "system-software-update" : "media-playback-start"
                            onClicked: {
                                if (!haManager) return;
                                if (eDom === "update") haManager.callService("update", "install", modelData, {});
                                else haManager.callService(eDom, "press", modelData, {});
                            }
                        }

                        PlasmaComponents3.ComboBox {
                            visible: (eDom === "select" || eDom === "input_select") && eObj && eObj.attributes && eObj.attributes.options
                            model: (eObj && eObj.attributes && eObj.attributes.options) ? eObj.attributes.options : []
                            currentIndex: (model && eObj) ? model.indexOf(eObj.state) : 0
                            onActivated: {
                                if (haManager) {
                                    haManager.callService(eDom, "select_option", modelData, { option: currentText });
                                }
                            }
                        }

                        Controls.SpinBox {
                            visible: (eDom === "number" || eDom === "input_number") && eObj && eObj.attributes
                            from: (eObj && eObj.attributes && eObj.attributes.min !== undefined) ? eObj.attributes.min : 0
                            to: (eObj && eObj.attributes && eObj.attributes.max !== undefined) ? eObj.attributes.max : 100
                            stepSize: (eObj && eObj.attributes && eObj.attributes.step) ? eObj.attributes.step : 1
                            value: eObj ? parseFloat(eObj.state) : 0
                            onValueModified: {
                                if (haManager) {
                                    haManager.callService(eDom, "set_value", modelData, { value: value });
                                }
                            }
                        }

                        Controls.TextField {
                            visible: (eDom === "text" || eDom === "input_text" || eDom === "date" || eDom === "time") && eObj
                            implicitWidth: Kirigami.Units.gridUnit * 8
                            text: eObj ? eObj.state : ""
                            placeholderText: eDom === "date" ? "YYYY-MM-DD" : (eDom === "time" ? "HH:MM:SS" : "")
                            onAccepted: {
                                if (!haManager || !eObj || text === eObj.state) return;
                                if (eDom === "date") haManager.callService("date", "set_value", modelData, { date: text });
                                else if (eDom === "time") haManager.callService("time", "set_value", modelData, { time: text });
                                else haManager.callService(eDom, "set_value", modelData, { value: text });
                            }
                        }

                        PlasmaComponents3.Switch {
                            visible: eDom === "switch" || eDom === "input_boolean"
                            checked: eObj ? (eObj.state === "on") : false
                            onToggled: {
                                if (haManager) {
                                    haManager.callService(eDom, checked ? "turn_on" : "turn_off", modelData, {});
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
