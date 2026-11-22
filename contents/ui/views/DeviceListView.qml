import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "../components" as Components
import "../../code/ha_helpers.js" as HAHelpers

ColumnLayout {
    id: listViewRoot

    property var haManager: null
    property string favoriteEntities: ""
    property int activeTab: 0
    property bool showDashboardTab: false

    signal configureRequested()
    signal openDetailsRequested(string entId)

    readonly property int revision: haManager ? haManager.entitiesRevision : 0

    readonly property var favoriteEntitiesList: {
        var raw = listViewRoot.favoriteEntities ? listViewRoot.favoriteEntities.trim() : "";
        if (!raw || raw === "[]") return [];
        try {
            var parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                return parsed.map(function(item) {
                    return item ? item.toString().replace(/['"\[\]]/g, "").trim() : "";
                }).filter(function(item) { return item.length > 0; });
            }
        } catch(e) {}
        return raw.split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
    }

    function sortEntitiesByName(list) {
        if (!Array.isArray(list) || list.length === 0) return [];
        return list.slice().sort(function(a, b) {
            var cleanA = a ? a.toString().replace(/['"\[\]]/g, "").trim() : "";
            var cleanB = b ? b.toString().replace(/['"\[\]]/g, "").trim() : "";

            var entA = haManager ? haManager.getEntity(cleanA) : null;
            var devIdA = haManager ? (haManager.entityToDeviceMap[cleanA] || "") : "";
            var titleA = (HAHelpers && typeof HAHelpers.getDeviceTitle === "function")
                ? (HAHelpers.getDeviceTitle(cleanA, entA, devIdA, haManager) || cleanA)
                : cleanA;

            var entB = haManager ? haManager.getEntity(cleanB) : null;
            var devIdB = haManager ? (haManager.entityToDeviceMap[cleanB] || "") : "";
            var titleB = (HAHelpers && typeof HAHelpers.getDeviceTitle === "function")
                ? (HAHelpers.getDeviceTitle(cleanB, entB, devIdB, haManager) || cleanB)
                : cleanB;

            titleA = titleA ? titleA.toString().trim() : "";
            titleB = titleB ? titleB.toString().trim() : "";

            return titleA.localeCompare(titleB, undefined, { numeric: true, sensitivity: "base" });
        });
    }

    readonly property var rawEntitiesList: {
        var rev = listViewRoot.revision;
        if (activeTab === 1 || !listViewRoot.showDashboardTab) {
            return listViewRoot.favoriteEntitiesList;
        }
        return [];
    }

    readonly property var displayedEntitiesList: {
        var list = listViewRoot.rawEntitiesList || [];
        return listViewRoot.sortEntitiesByName(list);
    }

    spacing: Kirigami.Units.smallSpacing

    Item {
        visible: listViewRoot.showDashboardTab && listViewRoot.activeTab === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.94
            implicitHeight: devCardCol.implicitHeight + Kirigami.Units.gridUnit * 1.5
            radius: 12
            color: Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
            border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.55)
            border.width: 1.5

            ColumnLayout {
                id: devCardCol
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit * 0.9
                spacing: Kirigami.Units.smallSpacing * 1.5

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 1.2
                    Layout.alignment: Qt.AlignHCenter

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
                        font.pointSize: Qt.application.font.pointSize * 1.15
                        color: Kirigami.Theme.textColor
                    }
                }

                PlasmaComponents3.Label {
                    text: i18n("This section is actively under development.\n\nPlease share your vision of how the dashboard should look and what cards it should contain.\n\nSend your feedback and concepts to the project email or join development on GitHub!")
                    wrapMode: Text.WordWrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
                    color: Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.15
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.smallSpacing / 2

                    PlasmaComponents3.Button {
                        text: i18n("Send Feedback")
                        icon.name: "mail-message-new"
                        onClicked: Qt.openUrlExternally("mailto:unidevhub@gmail.com?subject=HA-Hub%20Dashboard%20Concept")
                    }

                    PlasmaComponents3.Button {
                        text: "GitHub"
                        icon.name: "vcs-normal"
                        onClicked: Qt.openUrlExternally("https://github.com/Uni-Dev-Hub/HA-hub")
                    }
                }
            }
        }
    }

    Item {
        visible: !listViewRoot.showDashboardTab || listViewRoot.activeTab === 1
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            visible: !listViewRoot.displayedEntitiesList || listViewRoot.displayedEntitiesList.length === 0
            anchors.centerIn: parent
            spacing: Kirigami.Units.mediumSpacing
            width: parent.width * 0.85

            Kirigami.Icon {
                source: "starred-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                text: i18n("No favorite devices")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.1
                color: Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: i18n("Open settings to add devices to favorites.")
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                text: i18n("Open Settings")
                icon.name: "configure"
                highlighted: true
                Layout.alignment: Qt.AlignHCenter
                onClicked: listViewRoot.configureRequested()
            }
        }

        ListView {
            id: mainListView
            visible: listViewRoot.displayedEntitiesList && listViewRoot.displayedEntitiesList.length > 0
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing / 2
            anchors.bottomMargin: Kirigami.Units.smallSpacing

            clip: true
            spacing: Kirigami.Units.smallSpacing * 1.2

            PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                active: true
            }

            model: listViewRoot.displayedEntitiesList

            delegate: Components.NativeDeviceItem {
                width: mainListView.width - Kirigami.Units.gridUnit * 1.5
                entityId: modelData
                haManager: listViewRoot.haManager
                onOpenDetailsRequested: function(entId) {
                    listViewRoot.openDetailsRequested(entId);
                }
            }

            footer: Item {
                implicitWidth: mainListView.width
                implicitHeight: Kirigami.Units.gridUnit * 2.0
            }
        }
    }
}
