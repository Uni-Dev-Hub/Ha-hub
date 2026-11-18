import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../code/ha_helpers.mjs" as HAHelpers
import "../../../l10n"

Rectangle {
    id: infoSec
    required property var detailsPage
    required property var haManager

    Layout.fillWidth: true
    radius: 10
    color: Qt.alpha(Kirigami.Theme.textColor, 0.03)
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    implicitHeight: infoCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: infoCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.2
        spacing: 0

        Item {
            Layout.fillWidth: true
            implicitHeight: infoHeaderRow.implicitHeight + Kirigami.Units.smallSpacing

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: detailsPage.infoExpanded = !detailsPage.infoExpanded
            }

            RowLayout {
                id: infoHeaderRow
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon { source: "dialog-information"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small; color: Kirigami.Theme.disabledTextColor }
                PlasmaComponents3.Label {
                    text: Loc.t("Device Info & Entities (%1)", detailsPage.allDeviceEntities.length)
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.88
                    Layout.fillWidth: true
                }
                Kirigami.Icon {
                    source: detailsPage.infoExpanded ? "arrow-down" : "arrow-right"
                    implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }

        ColumnLayout {
            visible: detailsPage.infoExpanded
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing

            ColumnLayout {
                spacing: 3
                Layout.fillWidth: true
                RowLayout { PlasmaComponents3.Label { text: Loc.t("Manufacturer:"); color: Kirigami.Theme.disabledTextColor; font.pointSize: 8 } PlasmaComponents3.Label { text: (detailsPage.deviceRaw && detailsPage.deviceRaw.manufacturer) ? detailsPage.deviceRaw.manufacturer : "—"; font.bold: true; font.pointSize: 8 } }
                RowLayout { PlasmaComponents3.Label { text: Loc.t("Model:"); color: Kirigami.Theme.disabledTextColor; font.pointSize: 8 } PlasmaComponents3.Label { text: (detailsPage.deviceRaw && detailsPage.deviceRaw.model) ? detailsPage.deviceRaw.model : "—"; font.bold: true; font.pointSize: 8 } }
                RowLayout { PlasmaComponents3.Label { text: Loc.t("Firmware:"); color: Kirigami.Theme.disabledTextColor; font.pointSize: 8 } PlasmaComponents3.Label { text: (detailsPage.deviceRaw && detailsPage.deviceRaw.sw_version) ? detailsPage.deviceRaw.sw_version : "—"; font.pointSize: 8 } }
                RowLayout {
                    PlasmaComponents3.Label { text: Loc.t("Labels:"); color: Kirigami.Theme.disabledTextColor; font.pointSize: 8 }
                    PlasmaComponents3.Label {
                        text: HAHelpers.getLabelsText(detailsPage.deviceRaw ? detailsPage.deviceRaw.labels : [], haManager)
                        font.pointSize: 8
                        font.bold: true
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Repeater {
                model: detailsPage.allDeviceEntities
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    readonly property var eObj: haManager ? haManager.getEntity(modelData) : null

                    PlasmaComponents3.Label {
                        text: (eObj && eObj.attributes && eObj.attributes.friendly_name) ? eObj.attributes.friendly_name : modelData
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.Label {
                        text: {
                            if (!eObj || eObj.state === undefined) return "—";
                            var st = eObj.state;
                            if (st === "unavailable" || st === "unknown") return Loc.t("Unavailable");
                            if (st === "on") return Loc.t("On");
                            if (st === "off") return Loc.t("Off");
                            var u = (eObj.attributes && eObj.attributes.unit_of_measurement) ? (" " + eObj.attributes.unit_of_measurement) : "";
                            return st + u;
                        }
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        color: {
                            if (!eObj || eObj.state === "unavailable" || eObj.state === "unknown") return Kirigami.Theme.disabledTextColor;
                            if (eObj.state === "off") return Kirigami.Theme.disabledTextColor;
                            return Kirigami.Theme.positiveTextColor;
                        }
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }
    }
}
