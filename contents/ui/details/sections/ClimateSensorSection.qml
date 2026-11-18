import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

ColumnLayout {
    id: climSec
    required property var detailsPage
    required property var tempStatsService
    required property var humidityStatsService

    spacing: Kirigami.Units.smallSpacing * 1.4

    Rectangle {
        Layout.fillWidth: true
        radius: 12
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
        border.width: 1
        implicitHeight: climHeroCol.implicitHeight + Kirigami.Units.smallSpacing * 2.2

        ColumnLayout {
            id: climHeroCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.4
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: Loc.t("INDOOR CLIMATE")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
                Kirigami.Icon {
                    source: "temperature-normal"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.highlightColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    PlasmaComponents3.Label {
                        text: detailsPage.tempEntityObj ? (parseFloat(detailsPage.tempEntityObj.state).toFixed(1) + " " + (detailsPage.tempEntityObj.attributes.unit_of_measurement || "°C")) : "—"
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 1.65
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents3.Label {
                        text: {
                            if (!detailsPage.tempEntityObj) return "";
                            var t = parseFloat(detailsPage.tempEntityObj.state);
                            if (t > 26) return Loc.t("Hot");
                            if (t < 19) return Loc.t("Cool");
                            return Loc.t("Comfortable");
                        }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                ColumnLayout {
                    visible: detailsPage.humidityEntityObj !== null
                    spacing: 1
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignRight

                        PlasmaComponents3.Label {
                            text: detailsPage.humidityEntityObj ? (parseFloat(detailsPage.humidityEntityObj.state).toFixed(0) + " %") : ""
                            font.bold: true
                            font.pointSize: Qt.application.font.pointSize * 1.55
                            color: Kirigami.Theme.textColor
                        }
                    }
                    PlasmaComponents3.Label {
                        text: {
                            if (!detailsPage.humidityEntityObj) return "";
                            var h = parseFloat(detailsPage.humidityEntityObj.state);
                            if (h > 65) return Loc.t("Humid");
                            if (h < 35) return Loc.t("Dry");
                            return Loc.t("Normal humidity");
                        }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                        color: Kirigami.Theme.disabledTextColor
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }
    }

    Rectangle {
        visible: detailsPage.tempEntityId.length > 0 || detailsPage.humidityEntityId.length > 0
        Layout.fillWidth: true
        radius: 10
        color: Qt.alpha(Kirigami.Theme.textColor, 0.04)
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.09)
        border.width: 1
        implicitHeight: climStatCol.implicitHeight + Kirigami.Units.smallSpacing * 2.2

        ColumnLayout {
            id: climStatCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.2
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                visible: detailsPage.tempEntityId.length > 0
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "temperature-normal"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.highlightColor
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: Loc.t("Min Temp (24h)"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                    PlasmaComponents3.Label {
                        text: tempStatsService.todayMinStr
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: Loc.t("Avg Temp (24h)"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                    PlasmaComponents3.Label {
                        text: tempStatsService.todayAvgStr
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: Loc.t("Max Temp (24h)"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                    PlasmaComponents3.Label {
                        text: tempStatsService.todayMaxStr
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                    }
                }
            }

            Rectangle {
                visible: detailsPage.tempEntityId.length > 0 && detailsPage.humidityEntityId.length > 0
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
            }

            RowLayout {
                visible: detailsPage.humidityEntityId.length > 0
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "speedometer"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.highlightColor
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: Loc.t("Min Humidity"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                    PlasmaComponents3.Label {
                        text: humidityStatsService.todayMinStr
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: Loc.t("Avg Humidity"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                    PlasmaComponents3.Label {
                        text: humidityStatsService.todayAvgStr
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    PlasmaComponents3.Label { text: Loc.t("Max Humidity"); font.pointSize: 7.5; color: Kirigami.Theme.disabledTextColor }
                    PlasmaComponents3.Label {
                        text: humidityStatsService.todayMaxStr
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                    }
                }
            }
        }
    }
}
