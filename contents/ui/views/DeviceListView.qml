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
    property bool showSearchBar: false
    property string viewMode: "rows" // "rows", "tiles", "cards"
    property int cornerRadius: 14

    property int activeTab: Plasmoid.configuration.lastTab
    property string searchQuery: ""
    property string areaFilter: ""

    signal configureRequested()
    signal openDetailsRequested(string entId)

    readonly property int revision: haManager ? haManager.entitiesRevision : 0
    readonly property int listsRevision: haManager ? haManager.listsRevision : 0
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 18

    onActiveTabChanged: if (Plasmoid.configuration.lastTab !== activeTab) Plasmoid.configuration.lastTab = activeTab
    onShowSearchBarChanged: {
        if (showSearchBar) searchField.forceActiveFocus();
        else { searchQuery = ""; areaFilter = ""; }
    }

    readonly property var favoriteEntitiesList: {
        var raw = listViewRoot.favoriteEntities ? listViewRoot.favoriteEntities.trim() : "";
        if (!raw || raw === "[]") return [];
        try {
            var parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                return parsed.map(function(item) { return HAHelpers.cleanEntityId(item); })
                             .filter(function(item) { return item.length > 0; });
            }
        } catch (e) {}
        return raw.split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
    }

    readonly property var tabs: [
        { title: i18n("Favorites"), icon: "star",      tip: i18n("Favorite devices") },
        { title: i18n("Lights"),      icon: "lightbulb", tip: i18n("Lights, plugs and switches") },
        { title: i18n("Sensors"),   icon: "temperature", tip: i18n("Sensors and climate") },
        { title: i18n("More"),     icon: "speaker",   tip: i18n("Media, covers, locks, scenes and scripts") },
        { title: i18n("All"),     icon: "list",      tip: i18n("All visible entities") }
    ]

    readonly property var currentTabEntities: {
        var rev = listViewRoot.listsRevision;
        if (!haManager) return [];
        switch (listViewRoot.activeTab) {
        case 0: return listViewRoot.favoriteEntitiesList;
        case 1: return haManager.lightsAndSwitchesList || [];
        case 2: return haManager.climateAndSensorsList || [];
        case 3: return haManager.mediaAndOthersList || [];
        default: return haManager.allEntitiesList || [];
        }
    }

    // Areas that actually contain at least one listed entity
    readonly property var areaNames: {
        var rev = listViewRoot.listsRevision;
        if (!haManager || !haManager.areasList) return [];
        var names = haManager.areasList.map(function(a) { return a.name; }).filter(function(n) { return !!n; });
        names.sort(function(a, b) { return a.localeCompare(b); });
        return names;
    }

    readonly property var displayedEntitiesList: {
        var rev = listViewRoot.listsRevision;
        var query = listViewRoot.searchQuery.trim().toLowerCase();
        var area = listViewRoot.areaFilter;
        // Searching looks across every entity, not only the current tab
        var base = (query.length > 0 && haManager) ? (haManager.allEntitiesList || []) : currentTabEntities;
        if (query.length === 0 && area.length === 0) return base;

        return base.filter(function(entId) {
            var clean = HAHelpers.cleanEntityId(entId);
            var areaName = HAHelpers.getAreaName(clean, haManager);
            if (area.length > 0 && areaName !== area) return false;
            if (query.length === 0) return true;
            if (clean.toLowerCase().indexOf(query) !== -1) return true;
            var title = HAHelpers.getEntityTitle(clean, haManager.getEntity(clean)).toLowerCase();
            return title.indexOf(query) !== -1 || areaName.toLowerCase().indexOf(query) !== -1;
        });
    }

    spacing: Kirigami.Units.smallSpacing

    // ── Search + room filter ───────────────────────────────────────────
    RowLayout {
        visible: listViewRoot.showSearchBar
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: i18n("Search by name, room or ID…")
            clearButtonShown: true
            text: listViewRoot.searchQuery
            onTextChanged: listViewRoot.searchQuery = text
            Keys.onEscapePressed: {
                if (text.length > 0) text = "";
                else listViewRoot.showSearchBar = false;
            }
        }

        PlasmaComponents3.ComboBox {
            visible: listViewRoot.areaNames.length > 0
            implicitWidth: listViewRoot.narrow ? Kirigami.Units.gridUnit * 6 : Kirigami.Units.gridUnit * 8
            Layout.preferredHeight: searchField.implicitHeight
            model: [i18n("All rooms")].concat(listViewRoot.areaNames)
            currentIndex: listViewRoot.areaFilter ? Math.max(0, listViewRoot.areaNames.indexOf(listViewRoot.areaFilter) + 1) : 0
            onActivated: function(index) {
                listViewRoot.areaFilter = index <= 0 ? "" : listViewRoot.areaNames[index - 1];
            }
        }
    }

    // ── Category tabs ──────────────────────────────────────────────────
    PlasmaComponents3.TabBar {
        id: categoryTabBar
        Layout.fillWidth: true
        visible: listViewRoot.searchQuery.length === 0
        currentIndex: listViewRoot.activeTab
        onCurrentIndexChanged: if (listViewRoot.activeTab !== currentIndex) listViewRoot.activeTab = currentIndex

        readonly property bool showText: categoryTabBar.width > Kirigami.Units.gridUnit * 24

        Repeater {
            model: listViewRoot.tabs
            delegate: PlasmaComponents3.TabButton {
                required property var modelData
                text: modelData.title
                icon.source: Qt.resolvedUrl("../../icons/" + modelData.icon + ".svg")
                display: categoryTabBar.showText ? PlasmaComponents3.AbstractButton.TextBesideIcon
                                                 : PlasmaComponents3.AbstractButton.IconOnly
                PlasmaComponents3.ToolTip.visible: hovered && !categoryTabBar.showText
                PlasmaComponents3.ToolTip.text: modelData.tip
            }
        }
    }

    // ── Content ────────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        readonly property bool isEmpty: listViewRoot.displayedEntitiesList.length === 0

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 2
            visible: parent.isEmpty
            icon.source: {
                if (listViewRoot.searchQuery.length > 0) return Qt.resolvedUrl("../../icons/search.svg");
                return Qt.resolvedUrl("../../icons/" + listViewRoot.tabs[Math.min(listViewRoot.activeTab, 4)].icon + ".svg");
            }
            text: {
                if (listViewRoot.searchQuery.length > 0) return i18n("No results for “%1”", listViewRoot.searchQuery);
                if (listViewRoot.areaFilter.length > 0) return i18n("Nothing here in %1", listViewRoot.areaFilter);
                if (listViewRoot.activeTab === 0) return i18n("No favorites");
                if (!haManager || haManager.allEntitiesList.length === 0) return i18n("Loading…");
                return i18n("No entities in this category");
            }
            explanation: (listViewRoot.activeTab === 0 && listViewRoot.searchQuery.length === 0 && listViewRoot.areaFilter.length === 0)
                ? i18n("Hover a device and click the star, or right-click it.")
                : ""
            helpfulAction: (listViewRoot.activeTab === 0 && listViewRoot.searchQuery.length === 0) ? exploreAction : null

            Kirigami.Action {
                id: exploreAction
                text: i18n("Browse all devices")
                icon.name: "view-list-tree-symbolic"
                onTriggered: listViewRoot.activeTab = 4
            }
        }

        // Rows
        ListView {
            id: rowsListView
            visible: listViewRoot.viewMode === "rows" && !parent.isEmpty
            anchors.fill: parent
            clip: true
            spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)
            reuseItems: true
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

            PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar { id: rowsScroll }

            model: visible ? listViewRoot.displayedEntitiesList : []

            delegate: Components.CompactDeviceRow {
                required property var modelData
                width: rowsListView.width - (rowsScroll.visible ? rowsScroll.width + Kirigami.Units.smallSpacing : 0)
                entityId: modelData
                haManager: listViewRoot.haManager
                cornerRadius: listViewRoot.cornerRadius
                onOpenDetailsRequested: function(entId) { listViewRoot.openDetailsRequested(entId); }
            }
        }

        // Tiles & cards: column count adapts to the available width
        GridView {
            id: cardsGridView
            visible: listViewRoot.viewMode !== "rows" && !parent.isEmpty
            anchors.fill: parent
            clip: true
            reuseItems: true
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

            readonly property bool isCards: listViewRoot.viewMode === "cards"
            readonly property real usableWidth: width - (gridScroll.visible ? gridScroll.width : 0)
            readonly property real minCell: Kirigami.Units.gridUnit * (isCards ? 8 : 7.5)
            readonly property int columns: Math.max(1, Math.floor(usableWidth / minCell))

            cellWidth: Math.floor(usableWidth / columns)
            cellHeight: isCards
                ? Math.round(Math.max(Kirigami.Units.gridUnit * 7.5, Math.min(cellWidth * 0.9, Kirigami.Units.gridUnit * 9)))
                : Math.round(Kirigami.Units.gridUnit * 3.9)

            PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar { id: gridScroll }

            model: visible ? listViewRoot.displayedEntitiesList : []

            delegate: Item {
                id: cell
                required property var modelData
                width: cardsGridView.cellWidth
                height: cardsGridView.cellHeight

                Loader {
                    anchors.fill: parent
                    anchors.margins: Math.round(Kirigami.Units.smallSpacing * (cardsGridView.isCards ? 1 : 0.5))
                    sourceComponent: cardsGridView.isCards ? glassCardComp : tileComp
                    onLoaded: item.entityId = Qt.binding(function() { return cell.modelData; })
                }
            }

            Component {
                id: glassCardComp
                Components.GlassDeviceCard {
                    haManager: listViewRoot.haManager
                    cornerRadius: listViewRoot.cornerRadius
                    onOpenDetailsRequested: function(entId) { listViewRoot.openDetailsRequested(entId); }
                }
            }

            Component {
                id: tileComp
                Components.CompactDeviceTile {
                    haManager: listViewRoot.haManager
                    cornerRadius: listViewRoot.cornerRadius
                    onOpenDetailsRequested: function(entId) { listViewRoot.openDetailsRequested(entId); }
                }
            }
        }
    }
}
