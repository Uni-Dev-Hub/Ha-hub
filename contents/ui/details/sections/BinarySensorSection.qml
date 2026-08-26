import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../code/ha_helpers.js" as HAHelpers

ColumnLayout {
    id: binSec
    required property var detailsPage
    required property var binaryStatsService

    spacing: Kirigami.Units.smallSpacing * 1.4

    Rectangle {
        Layout.fillWidth: true
        radius: 12
        color: {
            var isOn = detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.state === "on";
            var dc = detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.attributes ? detailsPage.primaryEntityObj.attributes.device_class : "";
            if (isOn) {
                return (["moisture", "smoke", "gas", "safety", "problem"].indexOf(dc) !== -1)
                    ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.14)
                    : Qt.alpha(Kirigami.Theme.highlightColor, 0.12);
            }
            return Qt.alpha(Kirigami.Theme.textColor, 0.04);
        }
        border.color: {
            var isOn2 = detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.state === "on";
            return isOn2 ? Qt.alpha(Kirigami.Theme.highlightColor, 0.35) : Qt.alpha(Kirigami.Theme.textColor, 0.08);
        }
        border.width: 1
        implicitHeight: binHeroCol.implicitHeight + Kirigami.Units.smallSpacing * 2.2

        ColumnLayout {
            id: binHeroCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.4
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: i18n("SENSOR STATE")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
                Kirigami.Icon {
                    source: HAHelpers.getBinarySensorIcon(detailsPage.primaryEntityObj ? detailsPage.primaryEntityObj.attributes.device_class : "", detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.state === "on")
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: (detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.state === "on") ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: HAHelpers.getBinarySensorStateTitle(detailsPage.primaryEntityObj ? detailsPage.primaryEntityObj.state : "off", detailsPage.primaryEntityObj ? detailsPage.primaryEntityObj.attributes.device_class : "")
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.65
                    color: {
                        var isOn3 = detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.state === "on";
                        var dc3 = detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.attributes ? detailsPage.primaryEntityObj.attributes.device_class : "";
                        if (isOn3) {
                            return (["moisture", "smoke", "gas", "safety", "problem"].indexOf(dc3) !== -1)
                                ? Kirigami.Theme.negativeTextColor
                                : Kirigami.Theme.highlightColor;
                        }
                        return Kirigami.Theme.textColor;
                    }
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                spacing: 5
                Rectangle {
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: (detailsPage.primaryEntityObj && detailsPage.primaryEntityObj.state === "on") ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
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

    Rectangle {
        Layout.fillWidth: true
        radius: 10
        color: Qt.alpha(Kirigami.Theme.textColor, 0.035)
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
        border.width: 1
        implicitHeight: binStatsCol.implicitHeight + Kirigami.Units.smallSpacing * 2

        ColumnLayout {
            id: binStatsCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.2
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: i18n("ACTIVITY & EVENTS")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: i18n("Today: %1", binaryStatsService.todayTriggersCount)
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                    color: Kirigami.Theme.textColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: i18n("Last state change:")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: HAHelpers.formatLastChangedDate(detailsPage.primaryEntityObj ? detailsPage.primaryEntityObj.last_changed : null, "—")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                    color: Kirigami.Theme.textColor
                }
            }

            ColumnLayout {
                visible: binaryStatsService.binaryEventsList.length > 0
                Layout.fillWidth: true
                spacing: 2
                Layout.topMargin: Kirigami.Units.smallSpacing / 2

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                }

                Repeater {
                    model: binaryStatsService.binaryEventsList
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            text: modelData.timeStr
                            font.pointSize: 7.5
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                        }

                        PlasmaComponents3.Label {
                            text: i18n("Lasted %1", modelData.durationStr)
                            font.bold: true
                            font.pointSize: 7.5
                            color: Kirigami.Theme.textColor
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }
        }
    }
}
