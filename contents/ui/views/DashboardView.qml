pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../components" as Components
import "../../code/dashboard_model.mjs" as DashboardModel
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

// The Metro dashboard. The view owns both halves of the design:
// - geometry: the column count flows down and each group derives its tile
//   unit from its width only, so no child can resize the grid (feedback loop);
// - data: rebuildTileData() precomputes every presentation string once per
//   debounced burst of Home Assistant state changes, so the tile delegates
//   themselves never call helper modules from bindings.
Item {
    id: dashboardRoot

    property var haManager: null
    // JSON of the configured tile groups; when empty the legacy v1.0 card
    // list (legacyCardsJson) is migrated into one untitled group on the fly.
    property string groupsJson: ""
    property string legacyCardsJson: ""
    // Number of 1x1 tile units across the grid.
    property int columns: 4
    // Global tile content default: "both" | "title" | "icon".
    property string tileContent: "both"

    signal configureRequested()
    signal openDetailsRequested(string entId)

    readonly property var groups: {
        var all = DashboardModel.normalizeDashboardModel(groupsJson, legacyCardsJson);
        // A group with no tiles is a configuration leftover, not content.
        var visible = [];
        for (var i = 0; i < all.length; i++) {
            if (all[i].tiles.length > 0) visible.push(all[i]);
        }
        return visible;
    }

    // Presentation map: entityId -> { title, status, icon, domain, kind,
    // isOn, unavailable }. Tiles read from it; it is replaced as a whole.
    property var tileById: ({})

    // Triggers for a rebuild. State events are debounced: one HA burst used
    // to re-resolve every tile on every single message.
    readonly property int liveRevision: haManager ? haManager.entitiesRevision : 0
    readonly property bool managerConnected: haManager ? haManager.isConnected : false
    property string lang: Loc.language

    onLiveRevisionChanged: tileDataDebounce.restart()
    onManagerConnectedChanged: dashboardRoot.rebuildTileData()
    onGroupsJsonChanged: dashboardRoot.rebuildTileData()
    onLegacyCardsJsonChanged: dashboardRoot.rebuildTileData()
    onLangChanged: dashboardRoot.rebuildTileData()

    Timer {
        id: tileDataDebounce
        interval: 320
        onTriggered: dashboardRoot.rebuildTileData()
    }

    function rebuildTileData() {
        var out = {};
        var mgr = dashboardRoot.haManager;
        // Normalize the JSON strings directly: a *Changed signal is emitted
        // before dependent bindings have re-evaluated, so reading the `groups`
        // binding from inside the handler would rebuild from stale data.
        var all = DashboardModel.normalizeDashboardModel(
            dashboardRoot.groupsJson, dashboardRoot.legacyCardsJson);
        for (var g = 0; g < all.length; g++) {
            var tiles = all[g].tiles || [];
            for (var t = 0; t < tiles.length; t++) {
                var id = HAHelpers.cleanEntityId(tiles[t].entityId || "");
                if (!id || out[id]) continue;
                var ent = mgr ? mgr.getEntity(id) : null;
                var entry = mgr && mgr.getCatalogEntry ? mgr.getCatalogEntry(id) : null;
                var reg = mgr && mgr.getEntityRegistry ? mgr.getEntityRegistry(id) : null;
                var domain = HAHelpers.getDomain(id);
                var state = ent ? String(ent.state) : "";
                // Same action classes the device cards use for their switches.
                var kind = "view";
                if (["light", "switch", "input_boolean", "fan", "outlet"].indexOf(domain) !== -1) kind = "toggle";
                else if (["script", "scene", "button", "automation", "input_button"].indexOf(domain) !== -1) kind = "action";
                else if (domain === "lock") kind = "lock";
                out[id] = {
                    title: (entry && entry.name) ? entry.name
                        : HAHelpers.getEntityTitle(id, ent, reg, mgr),
                    status: ent ? HAHelpers.getStatusDetailsText(id, ent,
                        mgr && mgr.entityToDeviceMap ? (mgr.entityToDeviceMap[id] || "") : "",
                        mgr, dashboardRoot.lang) : "",
                    icon: (ent && ent.attributes && ent.attributes.icon)
                        ? ent.attributes.icon
                        : ((reg && reg.icon) ? reg.icon : HAHelpers.getDomainIcon(domain)),
                    domain: domain,
                    kind: kind,
                    isOn: state === "on" || state === "home" || state === "open"
                        || state === "playing" || state === "unlocked",
                    unavailable: !ent || state === "unavailable" || state === "unknown"
                };
            }
        }
        dashboardRoot.tileById = out;
    }

    Component.onCompleted: dashboardRoot.rebuildTileData()

    Item {
        anchors.centerIn: parent
        width: dashboardRoot.width * 0.86
        height: emptyColumn.implicitHeight
        visible: dashboardRoot.groups.length === 0

        ColumnLayout {
            id: emptyColumn
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: Kirigami.Units.mediumSpacing

            Kirigami.Icon {
                source: "view-grid-symbolic"
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents3.Label {
                text: Loc.t("Dashboard is empty")
                font.bold: true
                font.pointSize: Qt.application.font.pointSize * 1.1
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: Loc.t("Create tile groups in Settings → Dashboard.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                text: Loc.t("Open Settings")
                icon.name: "configure"
                highlighted: true
                Layout.alignment: Qt.AlignHCenter
                onClicked: dashboardRoot.configureRequested()
            }
        }
    }

    Flickable {
        id: dashboardFlick
        anchors.fill: parent
        visible: dashboardRoot.groups.length > 0
        clip: true
        contentWidth: width
        contentHeight: groupsColumn.implicitHeight

        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            active: true
        }

        ColumnLayout {
            id: groupsColumn
            width: dashboardFlick.width
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: dashboardRoot.groups

                delegate: Components.DashboardGroup {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    group: modelData
                    haManager: dashboardRoot.haManager
                    dataMap: dashboardRoot.tileById
                    columns: dashboardRoot.columns
                    defaultContent: dashboardRoot.tileContent
                    onOpenDetailsRequested: function(entId) {
                        dashboardRoot.openDetailsRequested(entId);
                    }
                }
            }
        }
    }
}
