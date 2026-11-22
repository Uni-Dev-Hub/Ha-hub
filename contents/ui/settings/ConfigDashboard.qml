pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Kirigami.ScrollablePage {
    id: dashboardSettings
    title: i18n("Dashboard")
    topPadding: Kirigami.Units.smallSpacing

    readonly property bool cfg_showDashboardDefault: false
    property bool cfg_showDashboard: false

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        width: parent.width

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Controls.Switch {
                id: showDashboardSwitch
                Kirigami.FormData.label: i18n("Widget Tab:")
                text: i18n("Show 'Dashboard' tab")
                checked: dashboardSettings.cfg_showDashboard
                onToggled: dashboardSettings.cfg_showDashboard = checked
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
            border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.55)
            border.width: 1.5
            implicitHeight: contentColumn.implicitHeight + Kirigami.Units.gridUnit * 1.5

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit * 0.9
                spacing: Kirigami.Units.mediumSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 1.2

                    Rectangle {
                        implicitWidth: Kirigami.Units.iconSizes.medium + 8
                        implicitHeight: Kirigami.Units.iconSizes.medium + 8
                        radius: 8
                        color: Kirigami.Theme.highlightColor

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source: "code-context"
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            color: Kirigami.Theme.highlightedTextColor
                        }
                    }

                    PlasmaComponents3.Label {
                        text: i18n("Section Under Development")
                        font.bold: true
                        font.pointSize: Qt.application.font.pointSize * 1.1
                        color: Kirigami.Theme.textColor
                    }
                }

                PlasmaComponents3.Label {
                    text: i18n("Please share your vision of what the dashboard should look like and contain.\n\nSend your ideas and concept descriptions to the project email or join development on GitHub!")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                    color: Kirigami.Theme.textColor
                    lineHeight: 1.2
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing / 2

                    PlasmaComponents3.Button {
                        text: i18n("Send Feedback (Email)")
                        icon.name: "mail-message-new"
                        onClicked: Qt.openUrlExternally("mailto:unidevhub@gmail.com?subject=HA-Hub%20Dashboard%20Concept")
                    }

                    PlasmaComponents3.Button {
                        text: i18n("Project on GitHub")
                        icon.name: "vcs-normal"
                        onClicked: Qt.openUrlExternally("https://github.com/Uni-Dev-Hub/HA-hub")
                    }
                }
            }
        }
    }
}
