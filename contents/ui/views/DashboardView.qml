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
    // Type for the tile text (Settings -> Dashboard). An empty family means the
    // theme's font and a size of 0 the size a tile is designed at.
    property string fontFamily: ""
    property real fontSize: 0

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
    // A rename has to re-title the tiles immediately, not on the next state
    // event - the manager counts its own revisions for exactly this.
    readonly property int aliasRevision: (haManager && haManager.aliasesRevision !== undefined)
        ? haManager.aliasesRevision : 0
    property string lang: Loc.language

    onLiveRevisionChanged: tileDataDebounce.restart()
    onManagerConnectedChanged: dashboardRoot.rebuildTileData()
    onAliasRevisionChanged: dashboardRoot.rebuildTileData()
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
                var status = ent ? HAHelpers.getStatusDetailsText(id, ent,
                    mgr && mgr.entityToDeviceMap ? (mgr.entityToDeviceMap[id] || "") : "",
                    mgr, dashboardRoot.lang) : "";
                // Same action classes the device cards use for their switches.
                var kind = "view";
                if (["light", "switch", "input_boolean", "fan", "outlet"].indexOf(domain) !== -1) kind = "toggle";
                else if (["script", "scene", "button", "automation", "input_button"].indexOf(domain) !== -1) kind = "action";
                else if (domain === "lock") kind = "lock";
                // Tiles live and die by their state line, so a dimmable light
                // that is on also reports how bright it is (tooltip text).
                var attrs = (ent && ent.attributes) ? ent.attributes : {};
                if (domain === "light" && state === "on"
                    && attrs.brightness !== undefined && attrs.brightness !== null) {
                    status += " • " + Math.round(Number(attrs.brightness) / 2.55) + "%";
                }
                // The row-end answer: switches get a switch, measurables a
                // value, everything else one honest state pictogram.
                var trailing = "icon";
                var valueText = "";
                var stateIcon = "";
                if (kind === "toggle") {
                    trailing = "switch";
                } else if (domain === "climate" || domain === "water_heater") {
                    if (attrs.current_temperature !== undefined && attrs.current_temperature !== null) {
                        trailing = "value";
                        var tUnit = attrs.temperature_unit || attrs.unit_of_measurement || "";
                        valueText = String(attrs.current_temperature) + (tUnit ? " " + tUnit : "");
                    }
                } else if (domain === "weather") {
                    if (attrs.temperature !== undefined && attrs.temperature !== null) {
                        trailing = "value";
                        valueText = String(attrs.temperature)
                            + (attrs.temperature_unit ? " " + attrs.temperature_unit : "");
                    }
                } else if (domain === "humidifier") {
                    if (attrs.current_humidity !== undefined && attrs.current_humidity !== null) {
                        trailing = "value";
                        valueText = String(attrs.current_humidity) + " %";
                    }
                } else if (domain === "cover") {
                    if (attrs.current_position !== undefined && attrs.current_position !== null) {
                        trailing = "value";
                        valueText = attrs.current_position + "%";
                    }
                    stateIcon = state === "open" ? "go-up-symbolic" : "go-down-symbolic";
                } else if (["sensor", "number", "input_number"].indexOf(domain) !== -1) {
                    trailing = "value";
                    valueText = status;
                } else if (domain === "lock") {
                    stateIcon = state === "locked" ? "object-locked-symbolic" : "object-unlocked-symbolic";
                } else if (domain === "binary_sensor") {
                    stateIcon = HAHelpers.getBinarySensorIcon(attrs.device_class, state === "on");
                } else if (domain === "media_player") {
                    stateIcon = state === "playing" ? "media-playback-start-symbolic"
                                                            : "media-playback-pause-symbolic";
                } else if (["scene", "script", "automation", "button", "input_button"].indexOf(domain) !== -1) {
                    stateIcon = "media-playback-start-symbolic";
                } else if (domain === "person") {
                    stateIcon = "user-identity-symbolic";
                } else {
                    stateIcon = HAHelpers.getDomainIcon(domain);
                }
                // The entity's own icon, as Home Assistant spells it. mdi:
                // names are drawn from the bundled font so the tile shows the
                // very glyph the user picked; anything else takes the domain
                // icon, which is also what an unloaded font falls back to.
                var rawIcon = (ent && ent.attributes && ent.attributes.icon)
                    ? ent.attributes.icon
                    : (reg && reg.icon ? reg.icon : "");
                var resolvedIcon = HAHelpers.resolveEntityIcon(rawIcon, domain);
                // The name the user typed for this entity outranks what Home
                // Assistant calls it - and outranks the catalog entry, whose
                // name was computed before the rename happened.
                var alias = (mgr && mgr.entityAliasFor) ? mgr.entityAliasFor(id) : "";
                out[id] = {
                    title: alias ? alias
                        : ((entry && entry.name) ? entry.name
                            : HAHelpers.getEntityTitle(id, ent, reg, mgr)),
                    status: status,
                    valueText: valueText,
                    trailing: trailing,
                    stateIcon: stateIcon,
                    icon: resolvedIcon.name,
                    iconKind: resolvedIcon.kind,
                    fallbackIcon: HAHelpers.getDomainIcon(domain),
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
            spacing: Kirigami.Units.mediumSpacing

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
                    tileFontFamily: dashboardRoot.fontFamily
                    tilePointSize: dashboardRoot.fontSize
                    onOpenDetailsRequested: function(entId) {
                        dashboardRoot.openDetailsRequested(entId);
                    }
                }
            }
        }
    }
}
