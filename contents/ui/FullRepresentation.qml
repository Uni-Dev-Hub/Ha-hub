import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "views" as Views
import "details" as Details

PlasmaComponents3.Page {
    id: fullRoot

    property var haManager: null
    property string favoriteEntities: ""
    property string activeDetailEntityId: ""
    property bool drawOwnBackground: false

    property bool showSearchBar: false
    property string viewMode: Plasmoid.configuration.viewMode || "rows"
    readonly property int cornerRadius: Plasmoid.configuration.cornerRadius
    readonly property real backgroundOpacity: Plasmoid.configuration.backgroundOpacity / 100

    signal configureRequested()

    // Small minimums: the widget can be shrunk freely on the desktop or in the popup
    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
    Layout.minimumHeight: Kirigami.Units.gridUnit * 9
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 24

    padding: drawOwnBackground ? Kirigami.Units.smallSpacing * 1.5 : 0
    topPadding: padding
    Keys.onEscapePressed: {
        if (activeDetailEntityId.length > 0) activeDetailEntityId = "";
        else if (showSearchBar) showSearchBar = false;
    }

    function setViewMode(mode) {
        fullRoot.viewMode = mode;
        Plasmoid.configuration.viewMode = mode;
    }

    background: Item {
        visible: fullRoot.drawOwnBackground

        Rectangle {
            id: bgBody
            anchors.fill: parent
            radius: fullRoot.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Kirigami.Theme.backgroundColor, Math.min(1, fullRoot.backgroundOpacity + 0.06)) }
                GradientStop { position: 1.0; color: Qt.alpha(Kirigami.Theme.backgroundColor, fullRoot.backgroundOpacity) }
            }
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        }
        // Glass sheen
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            anchors.bottomMargin: parent.height * 0.6
            radius: fullRoot.cornerRadius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    header: Views.HeaderView {
        visible: fullRoot.activeDetailEntityId.length === 0
        fullRoot: fullRoot
        haManager: fullRoot.haManager
        onConfigureRequested: fullRoot.configureRequested()
        onToggleSearchRequested: fullRoot.showSearchBar = !fullRoot.showSearchBar
        onViewModeSelected: function(mode) { fullRoot.setViewMode(mode); }
    }

    Loader {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing
        sourceComponent: {
            // Keep the device list visible while reconnecting if we already have data
            var hasData = haManager && haManager.allEntitiesList && haManager.allEntitiesList.length > 0;
            if (!haManager || (!haManager.isConnected && !hasData)) return authWizardComp;
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
            showSearchBar: fullRoot.showSearchBar
            viewMode: fullRoot.viewMode
            cornerRadius: fullRoot.cornerRadius
            enabled: fullRoot.haManager && fullRoot.haManager.isConnected
            opacity: enabled ? 1 : 0.55
            onConfigureRequested: fullRoot.configureRequested()
            onOpenDetailsRequested: function(entId) { fullRoot.activeDetailEntityId = entId; }
        }
    }

    Component {
        id: authWizardComp
        Views.AuthWizardView {
            haManager: fullRoot.haManager
        }
    }
}
