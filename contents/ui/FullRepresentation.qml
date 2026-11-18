import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "views" as Views
import "details" as Details
import "../l10n"

PlasmaComponents3.Page {
    id: fullRoot

    property var haManager: null
    property string favoriteEntities: ""
    property string activeDetailEntityId: ""

    readonly property bool showDashboardTab: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.showDashboard || false) : false
    readonly property string dashboardCards: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.dashboardCards || "[]") : "[]"

    signal configureRequested()

    readonly property real preferredPanelWidth: Math.round(Kirigami.Units.gridUnit * 22)
    readonly property real preferredPanelHeight: Math.round(Kirigami.Units.gridUnit * 27)

    width: preferredPanelWidth
    height: preferredPanelHeight
    implicitWidth: preferredPanelWidth
    implicitHeight: preferredPanelHeight

    Layout.minimumWidth: preferredPanelWidth
    Layout.maximumWidth: preferredPanelWidth
    Layout.minimumHeight: preferredPanelHeight
    Layout.maximumHeight: preferredPanelHeight

    readonly property string userName: {
        if (!haManager || !haManager.isConnected) return "";
        var rev = haManager.entitiesRevision;
        var keys = Object.keys(haManager.entities);
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].startsWith("person.")) {
                var p = haManager.entities[keys[i]];
                if (p && p.attributes && p.attributes.friendly_name) {
                    return p.attributes.friendly_name;
                }
            }
        }
        return "";
    }

    readonly property string greetingText: {
        var hour = new Date().getHours();
        var greeting = Loc.t("Welcome");
        if (hour >= 5 && hour < 12) { greeting = Loc.t("Good morning"); }
        else if (hour >= 12 && hour < 18) { greeting = Loc.t("Good afternoon"); }
        else if (hour >= 18 && hour < 23) { greeting = Loc.t("Good evening"); }
        else { greeting = Loc.t("Good night"); }
        return fullRoot.userName.length > 0 ? (greeting + ", " + fullRoot.userName + "!") : (greeting + "!");
    }

    padding: Kirigami.Units.smallSpacing * 1.5

    header: ColumnLayout {
        spacing: 0
        visible: fullRoot.activeDetailEntityId.length === 0

        Views.HeaderView {
            fullRoot: fullRoot
            haManager: fullRoot.haManager
            Layout.fillWidth: true
            onConfigureRequested: fullRoot.configureRequested()
        }

        PlasmaComponents3.TabBar {
            id: mainTabBar
            visible: haManager && haManager.isConnected && fullRoot.showDashboardTab
            Layout.fillWidth: true

            PlasmaComponents3.TabButton {
                text: Loc.t("Dashboard")
                icon.name: "view-grid-symbolic"
            }

            PlasmaComponents3.TabButton {
                text: Loc.t("Devices")
                icon.name: "view-list-symbolic"
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (!haManager || !haManager.isConnected) return authWizardComp;
            if (fullRoot.activeDetailEntityId.length > 0) return detailsPageComp;
            return deviceViewComp;
        }
    }

    Component {
        id: detailsPageComp
        Details.DeviceDetailsPage {
            haManager: fullRoot.haManager
            primaryEntityId: fullRoot.activeDetailEntityId
            onBackRequested: fullRoot.activeDetailEntityId = ""
        }
    }

    Component {
        id: deviceViewComp
        Views.DeviceListView {
            haManager: fullRoot.haManager
            favoriteEntities: fullRoot.favoriteEntities
            activeTab: fullRoot.showDashboardTab ? mainTabBar.currentIndex : 1
            showDashboardTab: fullRoot.showDashboardTab
            dashboardCards: fullRoot.dashboardCards
            onConfigureRequested: fullRoot.configureRequested()
            onOpenDetailsRequested: function(entId) {
                fullRoot.activeDetailEntityId = entId;
            }
        }
    }

    Component {
        id: authWizardComp
        Views.AuthWizardView {
            haManager: fullRoot.haManager
        }
    }
}
