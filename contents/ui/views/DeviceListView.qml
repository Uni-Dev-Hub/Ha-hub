import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "../components" as Components
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

ColumnLayout {
    id: listViewRoot

    property var haManager: null
    property string favoriteEntities: ""
    property int activeTab: 0
    property bool showDashboardTab: false
    property string dashboardCards: "[]"

    signal configureRequested()
    signal openDetailsRequested(string entId)

    readonly property int revision: haManager ? haManager.entitiesRevision : 0

    // 0 = favorites, 1 = areas, 2 = all entities
    property int browserTab: 0
    property string searchText: ""
    readonly property string searchQuery: searchText

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

    function catalogEntry(entityId) {
        if (!listViewRoot.haManager) return null;
        var entry = listViewRoot.haManager.getCatalogEntry
            ? listViewRoot.haManager.getCatalogEntry(entityId)
            : null;
        if (entry) return entry;

        // Keep old favorites working even if the entity is not in the current
        // catalog (for example a temporarily unavailable integration).
        var ent = listViewRoot.haManager.getEntity(entityId);
        if (!ent) return null;
        return {
            id: entityId,
            entityId: entityId,
            name: (ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name : entityId,
            domain: HAHelpers.getDomain(entityId),
            deviceId: listViewRoot.haManager.entityToDeviceMap ? (listViewRoot.haManager.entityToDeviceMap[entityId] || "") : "",
            deviceName: "",
            areaId: "",
            areaName: "",
            category: null,
            hidden: false,
            disabled: false
        };
    }

    function matchesSearch(entityId) {
        var query = listViewRoot.searchQuery.toLowerCase().trim();
        if (query.length === 0) return true;
        var entry = listViewRoot.catalogEntry(entityId);
        if (!entry) return false;
        var haystack = [
            entry.name || "",
            entityId || "",
            entry.deviceName || "",
            entry.areaName || "",
            entry.domain || ""
        ].join(" ").toLowerCase();
        return haystack.indexOf(query) !== -1;
    }

    function isVisibleEntity(entityId) {
        var entry = listViewRoot.catalogEntry(entityId);
        if (!entry) return false;
        if (listViewRoot.haManager && listViewRoot.haManager._isEntityHiddenOrDisabled) {
            return !listViewRoot.haManager._isEntityHiddenOrDisabled(entry);
        }
        return !entry.hidden && !entry.disabled;
    }

    function sortEntityIds(ids) {
        return ids.slice().sort(function(a, b) {
            var ea = listViewRoot.catalogEntry(a);
            var eb = listViewRoot.catalogEntry(b);
            var ta = ((ea && ea.name) || a || "").toString().trim();
            var tb = ((eb && eb.name) || b || "").toString().trim();
            return ta.localeCompare(tb, undefined, { numeric: true, sensitivity: "base" });
        });
    }

    readonly property var favoriteIds: {
        var rev = listViewRoot.revision;
        var result = [];
        var seen = {};
        for (var i = 0; i < favoriteEntitiesList.length; i++) {
            var id = favoriteEntitiesList[i];
            if (!id || seen[id]) continue;
            if (!listViewRoot.isVisibleEntity(id)) continue;
            if (!listViewRoot.matchesSearch(id)) continue;
            seen[id] = true;
            result.push(id);
        }
        return result;
    }

    readonly property var allIds: {
        var rev = listViewRoot.revision;
        if (!listViewRoot.haManager) return [];
        var result = [];
        var source = listViewRoot.haManager.userDevicesList || [];
        for (var i = 0; i < source.length; i++) {
            var id = source[i];
            if (!listViewRoot.isVisibleEntity(id)) continue;
            if (!listViewRoot.matchesSearch(id)) continue;
            result.push(id);
        }
        return result;
    }

    readonly property var areaRows: {
        var rev = listViewRoot.revision;
        if (!listViewRoot.haManager) return [];
        var groups = listViewRoot.haManager.areaGroups || [];
        var result = [];
        for (var g = 0; g < groups.length; g++) {
            var group = groups[g];
            var ids = [];
            for (var i = 0; i < (group.entityIds || []).length; i++) {
                var id = group.entityIds[i];
                if (!listViewRoot.isVisibleEntity(id)) continue;
                if (!listViewRoot.matchesSearch(id)) continue;
                ids.push(id);
            }
            if (ids.length === 0) continue;
            result.push({
                kind: "header",
                title: (group.name || Loc.t("Unassigned")) + (group.floorName ? ("  ·  " + group.floorName) : ""),
                count: ids.length,
                areaId: group.areaId || ""
            });
            for (var j = 0; j < ids.length; j++) {
                result.push({ kind: "entity", entityId: ids[j] });
            }
        }
        return result;
    }

    readonly property var currentRows: {
        if (browserTab === 1) return areaRows;
        var ids = browserTab === 2 ? allIds : favoriteIds;
        var rows = [];
        for (var i = 0; i < ids.length; i++) {
            rows.push({ kind: "entity", entityId: ids[i] });
        }
        return rows;
    }

    readonly property bool showingDashboard: showDashboardTab && activeTab === 0

    spacing: Kirigami.Units.smallSpacing

    DashboardView {
        visible: listViewRoot.showingDashboard
        Layout.fillWidth: true
        Layout.fillHeight: true
        haManager: listViewRoot.haManager
        cardsJson: listViewRoot.dashboardCards
        onConfigureRequested: listViewRoot.configureRequested()
        onOpenDetailsRequested: function(entId) {
            listViewRoot.openDetailsRequested(entId);
        }
    }

    Item {
        visible: !listViewRoot.showingDashboard
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Controls.TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Loc.t("Search by name, area or entity ID…")
                text: listViewRoot.searchText
                onTextChanged: listViewRoot.searchText = text
                visible: true
            }

            PlasmaComponents3.TabBar {
                id: browserTabBar
                Layout.fillWidth: true
                visible: listViewRoot.favoriteIds.length > 0 || listViewRoot.allIds.length > 0
                currentIndex: listViewRoot.browserTab

                onCurrentIndexChanged: {
                    if (listViewRoot.browserTab !== currentIndex) {
                        listViewRoot.browserTab = currentIndex;
                    }
                }

                PlasmaComponents3.TabButton {
                    text: Loc.t("Favorites (%1)", listViewRoot.favoriteIds.length)
                }
                PlasmaComponents3.TabButton {
                    text: Loc.t("Areas")
                }
                PlasmaComponents3.TabButton {
                    text: Loc.t("All")
                }
            }

            ColumnLayout {
                visible: listViewRoot.currentRows.length === 0
                anchors.centerIn: parent
                spacing: Kirigami.Units.mediumSpacing
                width: parent.width * 0.85

                Kirigami.Icon {
                    source: listViewRoot.browserTab === 0 ? "starred-symbolic" : "view-list-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.huge
                    implicitHeight: Kirigami.Units.iconSizes.huge
                    color: Kirigami.Theme.disabledTextColor
                    Layout.alignment: Qt.AlignHCenter
                }

                PlasmaComponents3.Label {
                    text: listViewRoot.browserTab === 0 ? Loc.t("No favorite devices") : Loc.t("No devices found")
                    font.bold: true
                    font.pointSize: Qt.application.font.pointSize * 1.1
                    color: Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    text: listViewRoot.browserTab === 0
                        ? Loc.t("Open settings to add devices to favorites.")
                        : Loc.t("Try changing the search query or check the connection.")
                    wrapMode: Text.WordWrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.disabledTextColor
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Button {
                    visible: listViewRoot.browserTab === 0
                    text: Loc.t("Open Settings")
                    icon.name: "configure"
                    highlighted: true
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: listViewRoot.configureRequested()
                }
            }

            ListView {
                id: mainListView
                visible: listViewRoot.currentRows.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing * 1.2

                PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                    active: true
                }

                model: listViewRoot.currentRows

                delegate: Item {
                    id: listRow
                    required property var modelData
                    required property int index

                    width: mainListView.width - Kirigami.Units.gridUnit * 1.5
                    height: listRow.modelData.kind === "header"
                        ? headerLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                        : (entityLoader.item ? entityLoader.item.implicitHeight : 0)

                    PlasmaComponents3.Label {
                        id: headerLabel
                        visible: listRow.modelData.kind === "header"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: visible
                            ? ((listRow.modelData.title || "") + "  ·  " + (listRow.modelData.count || 0))
                            : ""
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    Loader {
                        id: entityLoader
                        visible: listRow.modelData.kind === "entity"
                        width: parent.width
                        height: item ? item.implicitHeight : 0
                        sourceComponent: entityDelegateComponent

                        property string entityId: listRow.modelData.entityId || ""

                        onLoaded: {
                            if (item) {
                                item.entityId = entityLoader.entityId;
                                item.haManager = listViewRoot.haManager;
                            }
                        }
                    }
                }

                footer: Item {
                    implicitWidth: mainListView.width
                    implicitHeight: Kirigami.Units.gridUnit * 2.0
                }
            }
        }
    }

    Component {
        id: entityDelegateComponent

        Components.NativeDeviceItem {
            width: parent ? parent.width : 0
            onOpenDetailsRequested: function(entId) {
                listViewRoot.openDetailsRequested(entId);
            }
        }
    }
}
