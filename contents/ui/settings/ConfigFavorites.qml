pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../services" as Services
import "../components" as Components
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

Kirigami.Page {
    id: favoritesSettings
    title: Loc.t("Favorite Devices")

    implicitWidth: Kirigami.Units.gridUnit * 34
    implicitHeight: Kirigami.Units.gridUnit * 28

    property string cfg_host: ""
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property string cfg_favoriteEntities: "[]"
    property bool cfg_showHiddenEntities: false
    property bool cfg_showDiagnosticEntities: false

    property int currentTab: 0

    property var favoriteSet: ({})
    property var favEntitiesArray: []

    Services.HAManager {
        id: haManager
        host: favoritesSettings.cfg_host
        port: parseInt(favoritesSettings.cfg_port) || 8123
        useSsl: favoritesSettings.cfg_useSsl
        includeHiddenEntities: favoritesSettings.cfg_showHiddenEntities
        includeDiagnosticEntities: favoritesSettings.cfg_showDiagnosticEntities
    }

    // Connect only once the page is actually shown for the first time (the
    // settings dialog builds every page up front); see ConfigDashboard.
    property bool managerStarted: false

    function maybeStartManager() {
        if (managerStarted) return;
        managerStarted = true;
        // HAManager prefers the shared credential store; startAutoConnect()
        // loads from it and connects when credentials exist.
        haManager.startAutoConnect();
    }

    Component.onCompleted: {
        if (visible) maybeStartManager();
        favoritesSettings.loadFavoriteSet();
    }
    onVisibleChanged: if (visible) maybeStartManager()

    onCfg_favoriteEntitiesChanged: {
        favoritesSettings.loadFavoriteSet();
    }

    function loadFavoriteSet() {
        var raw = cfg_favoriteEntities || "";
        var parsed = [];
        try { parsed = JSON.parse(raw); } catch(e) {
            parsed = raw.split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
        }
        var map = {};
        var list = [];
        if (Array.isArray(parsed)) {
            for (var i = 0; i < parsed.length; i++) {
                var clean = HAHelpers.cleanEntityId(parsed[i]);
                if (clean) {
                    map[clean] = true;
                    list.push(clean);
                }
            }
        }
        favoriteSet = map;
        favEntitiesArray = list;
    }

    function isFavorite(entityId) {
        if (!entityId) return false;
        var clean = HAHelpers.cleanEntityId(entityId);
        return !!favoriteSet[clean];
    }

    function toggleFavorite(entityId) {
        if (!entityId) return;
        var clean = HAHelpers.cleanEntityId(entityId);
        var currentMap = Object.assign({}, favoriteSet);
        var currentList = favEntitiesArray.slice();

        if (currentMap[clean]) {
            delete currentMap[clean];
            var idx = currentList.indexOf(clean);
            if (idx !== -1) currentList.splice(idx, 1);
        } else {
            currentMap[clean] = true;
            currentList.push(clean);
        }

        favoriteSet = currentMap;
        favEntitiesArray = currentList;
        cfg_favoriteEntities = JSON.stringify(currentList);
    }

    function moveFavorite(fromIndex, toIndex) {
        var currentList = favEntitiesArray.slice();
        var displayedList = favoritesSettings.filteredFavEntitiesList;

        if (fromIndex < 0 || fromIndex >= displayedList.length) return;
        if (toIndex < 0 || toIndex >= displayedList.length) return;

        var fromItem = displayedList[fromIndex];
        var toItem = displayedList[toIndex];

        var realFrom = currentList.indexOf(fromItem);
        var realTo = currentList.indexOf(toItem);

        if (realFrom === -1 || realTo === -1) return;

        var item = currentList.splice(realFrom, 1)[0];
        currentList.splice(realTo, 0, item);

        favEntitiesArray = currentList;
        cfg_favoriteEntities = JSON.stringify(currentList);
    }

    function getLiveDeviceInfo(entId) {
        var rev = haManager ? haManager.entitiesRevision : 0;
        var cleanId = HAHelpers.cleanEntityId(entId);
        if (!haManager || !cleanId) {
            return { title: entId || "", areaName: "", statusText: Loc.t("Unavailable"), isOn: false, isUnavailable: true };
        }

        var entObj = haManager.getEntity(cleanId);
        var regInfo = haManager.getEntityRegistry ? haManager.getEntityRegistry(cleanId) : null;
        var entry = haManager.getCatalogEntry ? haManager.getCatalogEntry(cleanId) : null;
        var title = entry && entry.name ? entry.name : HAHelpers.getEntityTitle(cleanId, entObj, regInfo, haManager);
        var areaName = HAHelpers.getAreaName(cleanId, haManager);
        var entry = haManager.getCatalogEntry ? haManager.getCatalogEntry(cleanId) : null;
        var deviceName = entry && entry.deviceName ? entry.deviceName : "";
        var domain = HAHelpers.getDomain(cleanId);
        var devId = entry && entry.deviceId ? entry.deviceId : (haManager.entityToDeviceMap ? (haManager.entityToDeviceMap[cleanId] || "") : "");
        var statusText = HAHelpers.getStatusDetailsText(cleanId, entObj, devId, haManager, Loc.language);

        var isUnavailable = (!entObj || entObj.state === "unavailable" || entObj.state === "unknown");
        var isOn = !isUnavailable && (entObj.state === "on" || entObj.state === "home" || entObj.state === "open" || entObj.state === "playing" || entObj.state === "unlocked");

        return {
            title: title,
            areaName: areaName,
            deviceName: deviceName,
            domain: domain,
            statusText: statusText,
            isOn: isOn,
            isUnavailable: isUnavailable
        };
    }

    readonly property var rawAllEntitiesList: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        return (haManager && haManager.userDevicesList) ? haManager.userDevicesList : [];
    }

    // domain -> count over the full list (chip labels never change while
    // filtering, only the rows below do).
    readonly property var domainCounts: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        var source = favoritesSettings.rawAllEntitiesList || [];
        var counts = {};
        for (var i = 0; i < source.length; i++) {
            var domain = HAHelpers.getDomain(source[i]);
            if (!domain) continue;
            counts[domain] = (counts[domain] || 0) + 1;
        }
        return counts;
    }

    readonly property var areaOptions: {
        var rev = haManager ? haManager.entitiesRevision : 0;
        var areas = (haManager && haManager.areasList) ? haManager.areasList : [];
        var result = [];
        for (var i = 0; i < areas.length; i++) {
            var id = areas[i].area_id || areas[i].id || "";
            if (!id) continue;
            result.push({ id: id, name: areas[i].name || id });
        }
        result.sort(function(a, b) { return a.name.localeCompare(b.name); });
        return result;
    }

    function entityMatchesFilters(entId) {
        var filterText = entityFilter.searchText.toLowerCase().trim();
        var domain = entityFilter.selectedDomain;
        var area = entityFilter.selectedArea;

        var info = favoritesSettings.getLiveDeviceInfo(entId);
        if (domain !== "all" && info.domain !== domain) return false;
        if (area !== "all") {
            var clean = HAHelpers.cleanEntityId(entId);
            var entry = haManager && haManager.getCatalogEntry ? haManager.getCatalogEntry(clean) : null;
            if (!entry || (entry.areaId || "") !== area) return false;
        }
        if (filterText.length === 0) return true;
        return info.title.toLowerCase().indexOf(filterText) !== -1 ||
               entId.toLowerCase().indexOf(filterText) !== -1 ||
               info.statusText.toLowerCase().indexOf(filterText) !== -1 ||
               info.areaName.toLowerCase().indexOf(filterText) !== -1 ||
               info.deviceName.toLowerCase().indexOf(filterText) !== -1 ||
               info.domain.toLowerCase().indexOf(filterText) !== -1;
    }

    readonly property var filteredAllEntitiesList: {
        var list = favoritesSettings.rawAllEntitiesList || [];
        // Read filter-bar properties here so this binding re-evaluates
        // when they change (method calls alone may not register deps).
        var tb = entityFilter.searchText;
        var d = entityFilter.selectedDomain;
        var a = entityFilter.selectedArea;
        return list.filter(function(entId) { return favoritesSettings.entityMatchesFilters(entId); });
    }

    readonly property var filteredFavEntitiesList: {
        var list = favoritesSettings.favEntitiesArray || [];
        var tb = entityFilter.searchText;
        var d = entityFilter.selectedDomain;
        var a = entityFilter.selectedArea;
        return list.filter(function(entId) { return favoritesSettings.entityMatchesFilters(entId); });
    }

    ColumnLayout {
        visible: haManager && (!haManager.isConnected || haManager.state === "AUTHENTICATING") && haManager.state !== "ERROR"
        anchors.centerIn: parent
        spacing: Kirigami.Units.mediumSpacing
        width: parent.width * 0.85

        PlasmaComponents3.BusyIndicator {
            running: parent.visible
            implicitWidth: Kirigami.Units.gridUnit * 2.5
            implicitHeight: Kirigami.Units.gridUnit * 2.5
            Layout.alignment: Qt.AlignHCenter
        }

        PlasmaComponents3.Label {
            text: Loc.t("Please wait, loading data...")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.15
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            text: haManager ? haManager.connectionStatus : Loc.t("Connecting to Home Assistant...")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        visible: haManager && haManager.state === "ERROR" && !haManager.isConnected
        anchors.centerIn: parent
        spacing: Kirigami.Units.mediumSpacing
        width: parent.width * 0.85

        Kirigami.Icon {
            source: "dialog-error-symbolic"
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            color: Kirigami.Theme.negativeTextColor
            Layout.alignment: Qt.AlignHCenter
        }

        PlasmaComponents3.Label {
            text: haManager ? haManager.connectionStatus : Loc.t("Connection Error")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            color: Kirigami.Theme.negativeTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        PlasmaComponents3.Button {
            text: Loc.t("Retry Connection")
            icon.name: "view-refresh-symbolic"
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                if (haManager) haManager.startAutoConnect();
            }
        }
    }

    ColumnLayout {
        visible: haManager && haManager.isConnected
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Components.EntityFilterBar {
                id: entityFilter
                Layout.fillWidth: true
                domainCounts: favoritesSettings.domainCounts
                areaOptions: favoritesSettings.areaOptions
            }

            PlasmaComponents3.TabBar {
                id: filterTabBar
                Layout.fillWidth: true
                currentIndex: favoritesSettings.currentTab

                onCurrentIndexChanged: {
                    if (favoritesSettings.currentTab !== currentIndex) {
                        favoritesSettings.currentTab = currentIndex;
                    }
                }

                PlasmaComponents3.TabButton {
                    text: Loc.t("All (%1)", favoritesSettings.rawAllEntitiesList.length)
                }
                PlasmaComponents3.TabButton {
                    text: Loc.t("Favorites (%1)", favoritesSettings.favEntitiesArray.length)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Controls.CheckBox {
                    text: Loc.t("Hidden")
                    checked: favoritesSettings.cfg_showHiddenEntities
                    onToggled: favoritesSettings.cfg_showHiddenEntities = checked
                }

                Controls.CheckBox {
                    text: Loc.t("Diagnostic / config")
                    checked: favoritesSettings.cfg_showDiagnosticEntities
                    onToggled: favoritesSettings.cfg_showDiagnosticEntities = checked
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Label {
                    text: Loc.t("%1 entities", favoritesSettings.rawAllEntitiesList.length)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.78
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ListView {
            id: devicesListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            rightMargin: Kirigami.Units.gridUnit * 1.5
            spacing: 2

            header: Item { width: 1; height: Kirigami.Units.mediumSpacing }
            footer: Item { width: 1; height: Kirigami.Units.mediumSpacing }

            PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                id: verticalScrollBar
                active: true
            }

            model: favoritesSettings.currentTab === 0
                ? favoritesSettings.filteredAllEntitiesList
                : favoritesSettings.filteredFavEntitiesList

            delegate: PlasmaComponents3.ItemDelegate {
                id: delegateRoot
                required property var modelData
                required property int index

                readonly property string entId: modelData ? modelData.toString() : ""
                readonly property bool isFav: favoritesSettings.isFavorite(entId)
                readonly property var liveInfo: favoritesSettings.getLiveDeviceInfo(entId)

                width: Math.max(200, devicesListView.width - devicesListView.rightMargin - Kirigami.Units.smallSpacing)
                implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

                topPadding: Kirigami.Units.smallSpacing * 1.2
                bottomPadding: Kirigami.Units.smallSpacing * 1.2
                leftPadding: Kirigami.Units.mediumSpacing
                rightPadding: Kirigami.Units.mediumSpacing

                onClicked: {
                    if (favoritesSettings.currentTab === 0 && delegateRoot.entId) {
                        favoritesSettings.toggleFavorite(delegateRoot.entId);
                    }
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.mediumSpacing

                    PlasmaComponents3.ToolButton {
                        icon.name: delegateRoot.isFav ? "starred-symbolic" : "non-starred-symbolic"
                        icon.color: delegateRoot.isFav ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            if (delegateRoot.entId) favoritesSettings.toggleFavorite(delegateRoot.entId);
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Layout.fillWidth: true

                            Rectangle {
                                visible: delegateRoot.liveInfo.areaName.length > 0
                                implicitWidth: areaLabelDesk.implicitWidth + 10
                                implicitHeight: areaLabelDesk.implicitHeight + 4
                                radius: 4
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.18)
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                PlasmaComponents3.Label {
                                    id: areaLabelDesk
                                    anchors.centerIn: parent
                                    text: delegateRoot.liveInfo.areaName.toUpperCase()
                                    font.bold: true
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.85
                                }
                            }

                            PlasmaComponents3.Label {
                                text: delegateRoot.liveInfo.title
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                font.bold: delegateRoot.isFav
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.alignment: Qt.AlignVCenter
                            }

                            PlasmaComponents3.Label {
                                text: delegateRoot.liveInfo.statusText
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                font.bold: delegateRoot.liveInfo.isOn
                                color: delegateRoot.liveInfo.isUnavailable
                                    ? Kirigami.Theme.disabledTextColor
                                    : (delegateRoot.liveInfo.isOn ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor)
                                elide: Text.ElideRight
                                Layout.maximumWidth: Math.round(delegateRoot.width * 0.4)
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            }
                        }

                        PlasmaComponents3.Label {
                            text: delegateRoot.liveInfo.deviceName.length > 0
                                ? (delegateRoot.entId + "  •  " + delegateRoot.liveInfo.deviceName)
                                : delegateRoot.entId
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                            opacity: 0.75
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                        }
                    }

                    RowLayout {
                        visible: favoritesSettings.currentTab === 1
                        spacing: Kirigami.Units.smallSpacing
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        PlasmaComponents3.ToolButton {
                            icon.name: "arrow-up-symbolic"
                            enabled: delegateRoot.index > 0
                            onClicked: favoritesSettings.moveFavorite(delegateRoot.index, delegateRoot.index - 1)
                        }

                        PlasmaComponents3.ToolButton {
                            icon.name: "arrow-down-symbolic"
                            enabled: delegateRoot.index < favoritesSettings.filteredFavEntitiesList.length - 1
                            onClicked: favoritesSettings.moveFavorite(delegateRoot.index, delegateRoot.index + 1)
                        }

                        PlasmaComponents3.ToolButton {
                            icon.name: "delete"
                            onClicked: {
                                if (delegateRoot.entId) favoritesSettings.toggleFavorite(delegateRoot.entId);
                            }
                        }
                    }
                }
            }
        }
    }
}
