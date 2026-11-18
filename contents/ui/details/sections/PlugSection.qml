import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../../l10n"

ColumnLayout {
    id: plugSec
    required property var detailsPage
    required property var energyStatsService

    spacing: Kirigami.Units.smallSpacing * 1.4

    Rectangle {
        Layout.fillWidth: true
        radius: 12
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.08)
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
        border.width: 1
        implicitHeight: heroCol.implicitHeight + Kirigami.Units.smallSpacing * 2

        ColumnLayout {
            id: heroCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.4
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: Loc.t("INSTANT POWER")
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
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: {
                        if (detailsPage.powerEntityObj && detailsPage.powerEntityObj.state !== undefined && !isNaN(detailsPage.powerEntityObj.state)) {
                            return parseFloat(detailsPage.powerEntityObj.state).toFixed(0) + " " + (detailsPage.powerEntityObj.attributes.unit_of_measurement || "W");
                        }
                        if (detailsPage.currentEntityObj && detailsPage.currentEntityObj.state !== undefined && !isNaN(detailsPage.currentEntityObj.state)) {
                            return parseFloat(detailsPage.currentEntityObj.state).toFixed(2) + " " + (detailsPage.currentEntityObj.attributes.unit_of_measurement || "A");
                        }
                        return "0 W";
                    }
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.55
                    color: Kirigami.Theme.textColor
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    PlasmaComponents3.Label {
                        visible: detailsPage.voltageEntityObj !== null
                        text: detailsPage.voltageEntityObj ? (parseFloat(detailsPage.voltageEntityObj.state).toFixed(0) + " " + (detailsPage.voltageEntityObj.attributes.unit_of_measurement || "V")) : ""
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                        color: Kirigami.Theme.textColor
                        Layout.alignment: Qt.AlignRight
                    }

                    PlasmaComponents3.Label {
                        visible: detailsPage.powerEntityObj !== null && detailsPage.currentEntityObj !== null
                        text: detailsPage.currentEntityObj ? (parseFloat(detailsPage.currentEntityObj.state).toFixed(2) + " " + (detailsPage.currentEntityObj.attributes.unit_of_measurement || "A")) : ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        color: Kirigami.Theme.disabledTextColor
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }

            RowLayout {
                spacing: 5
                Layout.topMargin: 2

                Rectangle {
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: {
                        if (!detailsPage.isTurnedOn) return Kirigami.Theme.disabledTextColor;
                        var pVal = detailsPage.powerEntityObj ? parseFloat(detailsPage.powerEntityObj.state) : (detailsPage.currentEntityObj ? parseFloat(detailsPage.currentEntityObj.state) : 0);
                        return pVal > 1.0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor;
                    }
                }

                PlasmaComponents3.Label {
                    text: {
                        if (!detailsPage.isTurnedOn) return Loc.t("Plug is off");
                        var pVal2 = detailsPage.powerEntityObj ? parseFloat(detailsPage.powerEntityObj.state) : (detailsPage.currentEntityObj ? parseFloat(detailsPage.currentEntityObj.state) : 0);
                        return pVal2 > 1.0 ? Loc.t("Active load") : Loc.t("On • Standby mode");
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82
                    color: detailsPage.isTurnedOn ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                }
            }
        }
    }

    ColumnLayout {
        visible: detailsPage.energyEntityId.length > 0
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        GridLayout {
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 3.6
                radius: 10
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
                border.width: 1

                Item {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing * 1.2
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        PlasmaComponents3.Label { text: Loc.t("Today"); font.pointSize: 8; color: Kirigami.Theme.disabledTextColor }
                        PlasmaComponents3.Label { text: energyStatsService.todayValueStr; font.bold: true; font.pointSize: Qt.application.font.pointSize * 1.2; color: Kirigami.Theme.textColor }
                    }
                    Kirigami.Icon { anchors.right: parent.right; anchors.top: parent.top; source: "speedometer"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small; color: Kirigami.Theme.highlightColor }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 3.6
                radius: 10
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
                border.width: 1

                Item {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing * 1.2
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        PlasmaComponents3.Label { text: Loc.t("This month"); font.pointSize: 8; color: Kirigami.Theme.disabledTextColor }
                        PlasmaComponents3.Label { text: energyStatsService.monthValueStr; font.bold: true; font.pointSize: Qt.application.font.pointSize * 1.2; color: Kirigami.Theme.textColor }
                    }
                    Kirigami.Icon { anchors.right: parent.right; anchors.top: parent.top; source: "view-calendar"; implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small; color: Kirigami.Theme.highlightColor }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: footRow.implicitHeight + Kirigami.Units.smallSpacing * 1.4
            radius: 8
            color: Qt.alpha(Kirigami.Theme.textColor, 0.035)
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
            border.width: 1

            RowLayout {
                id: footRow
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing * 1.2
                anchors.rightMargin: Kirigami.Units.smallSpacing * 1.2
                PlasmaComponents3.Label { text: Loc.t("Week: %1", energyStatsService.weekValueStr); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82; color: Kirigami.Theme.disabledTextColor; Layout.fillWidth: true }
                PlasmaComponents3.Label { text: Loc.t("Total: %1", energyStatsService.totalValueStr); font.bold: true; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.82; color: Kirigami.Theme.textColor; Layout.alignment: Qt.AlignRight }
            }
        }
    }

    Rectangle {
        visible: energyStatsService.last7DaysBreakdown.length > 0
        Layout.fillWidth: true
        radius: 12
        color: Qt.alpha(Kirigami.Theme.textColor, 0.035)
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
        border.width: 1
        implicitHeight: chartCol.implicitHeight + Kirigami.Units.smallSpacing * 2.2

        ColumnLayout {
            id: chartCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.2
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label { text: Loc.t("7-Day History"); font.bold: true; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85; color: Kirigami.Theme.textColor; Layout.fillWidth: true }
                PlasmaComponents3.Label { text: Loc.t("Max: %1 kWh", energyStatsService.max7DaysValue.toFixed(2)); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75; color: Kirigami.Theme.disabledTextColor }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 75
                spacing: Kirigami.Units.smallSpacing * 0.8

                Repeater {
                    model: energyStatsService.last7DaysBreakdown
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        PlasmaComponents3.ToolTip.visible: barMouseArea.containsMouse
                        PlasmaComponents3.ToolTip.text: modelData.dateStr + " (" + modelData.dayName + "): " + modelData.valStr + " kWh"

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle { anchors.fill: parent; radius: 4; color: Qt.alpha(Kirigami.Theme.textColor, 0.04) }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.75
                                height: Math.max(4, (modelData.val / Math.max(0.01, energyStatsService.max7DaysValue)) * parent.height)
                                radius: 4
                                color: modelData.isToday ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.28)
                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            }
                            MouseArea { id: barMouseArea; anchors.fill: parent; hoverEnabled: true }
                        }

                        PlasmaComponents3.Label {
                            text: modelData.dayName
                            font.bold: modelData.isToday
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.70
                            color: modelData.isToday ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
