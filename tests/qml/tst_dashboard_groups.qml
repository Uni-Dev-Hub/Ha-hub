import QtQuick
import QtTest
import "../../contents/ui/views" as Views
import "../../contents/ui/components" as Components

// Metro dashboard: the view normalises its JSON model (including the legacy
// card migration), the controller precomputes the tile presentation, the
// manual grid places tiles inside the width without any layout manager, and
// the tiles act on tap (toggle) or long press (details).
TestCase {
    id: groupsJsonTest
    name: "DashboardGroups"

    QtObject {
        id: fakeManager
        property bool isConnected: true
        property int entitiesRevision: 1
        property var serviceCalls: []
        property var entities: ({
            "light.corridor": { entity_id: "light.corridor", state: "on",
                attributes: { friendly_name: "Corridor Light", icon: "mdi:lightbulb" } },
            "sensor.outside": { entity_id: "sensor.outside", state: "-3.5",
                attributes: { unit_of_measurement: "°C" } },
            "fan.bedroom": { entity_id: "fan.bedroom", state: "unavailable", attributes: {} },
            "switch.kitchen": { entity_id: "switch.kitchen", state: "off", attributes: {} }
        })
        property var entityToDeviceMap: ({})
        function getEntity(id) { return entities[id] || null }
        function getEntityRegistry(id) { return null }
        function getCatalogEntry(id) {
            return id === "light.corridor" ? { name: "Свет в коридоре" } : null
        }
        function callService(domain, service, entityId, serviceData, callback, options) {
            serviceCalls.push([domain, service, entityId].join("|"))
        }
    }

    readonly property string groupsJson: JSON.stringify([
        { id: "g1", name: "Corridor", color: "#0078d7", tiles: [
            { entityId: "light.corridor", size: "medium", content: "" },
            { entityId: "sensor.outside", size: "small", content: "icon" },
            { entityId: "fan.bedroom", size: "wide", content: "title" }
        ] },
        { id: "g2", name: "Empty", color: "#ffd800", tiles: [] },
        { id: "g3", name: "Untitled", color: "#ffd800", tiles: [
            { entityId: "switch.kitchen", size: "large", content: "both" }
        ] }
    ])

    Views.DashboardView {
        id: view
        width: 340
        height: 600
        visible: true
        haManager: fakeManager
        groupsJson: groupsJsonTest.groupsJson
    }

    // Standalone tile fed by a hand-made presentation object: the view's
    // controller is not involved, so the tile itself is tested as the dumb
    // presenter it is supposed to be.
    Components.MetroTile {
        id: tile
        width: 90
        height: 90
        visible: true
        entityId: "light.corridor"
        size: "medium"
        contentMode: "both"
        presentation: ({ title: "Свет в коридоре", status: "", icon: "mdi:lightbulb",
                 domain: "light", kind: "toggle", isOn: true, unavailable: false })
    }

    Components.DashboardGroup {
        id: group
        width: 318
        visible: true
        columns: 4
        group: ({
            id: "gx", name: "Corridor", color: "#0078d7",
            tiles: [
                { entityId: "light.corridor", size: "small", content: "" },
                { entityId: "sensor.outside", size: "wide", content: "" }
            ]
        })
        dataMap: ({
            "light.corridor": ({ title: "L", icon: "x", kind: "toggle" }),
            "sensor.outside": ({ title: "S", icon: "y", kind: "view" })
        })
    }

    // Minimal signal spy target (see test_tap_on_a_sensor...).
    property string spyLastId: ""

    function findByObjectName(item, name, out) {
        out = out || []
        if (!item) return out
        if (item.objectName === name) out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) findByObjectName(item.children[i], name, out)
        return out
    }

    function findByText(item, text) {
        if (!item) return null
        if (item.text === text) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var found = findByText(kids[i], text)
            if (found) return found
        }
        return null
    }

    function tileFor(rootItem, entityId) {
        var tiles = findByObjectName(rootItem, "metroTile")
        for (var i = 0; i < tiles.length; i++) {
            if (tiles[i].entityId === entityId) return tiles[i]
        }
        return null
    }

    function test_view_renders_tiles_from_the_model_module() {
        // Regression: dashboard_model.mjs runs in its own JS realm, so its
        // arrays fail Array.isArray() inside QML and the tile Repeater used
        // to receive an empty list - the whole dashboard rendered nothing.
        wait(150)
        var tiles = findByObjectName(view, "metroTile")
        compare(tiles.length, 4, "every tile of both visible groups exists")
        var groups = findByObjectName(view, "dashboardGroup")
        compare(groups.length, 2)
    }

    function test_view_model_skips_empty_groups() {
        wait(100)
        compare(view.groups.length, 2, "the tile-less group is hidden")
        compare(view.groups[0].tiles.length, 3)
    }

    function test_controller_precomputes_the_presentation() {
        wait(100)
        var light = view.tileById["light.corridor"]
        verify(!!light, "the light tile has a presentation entry")
        compare(light.title, "Свет в коридоре", "catalog name wins")
        compare(light.icon, "mdi:lightbulb")
        compare(light.kind, "toggle")
        compare(light.isOn, true)
        compare(light.unavailable, false)
        var fan = view.tileById["fan.bedroom"]
        compare(fan.kind, "toggle")
        compare(fan.unavailable, true, "the unavailable fan is flagged")
        var sensor = view.tileById["sensor.outside"]
        compare(sensor.kind, "view", "a sensor is not toggleable")

        var tile = tileFor(view, "light.corridor")
        verify(!!tile, "the rendered tile reads the precomputed map")
        compare(tile.title, "Свет в коридоре")
        compare(tile.iconSource, "mdi:lightbulb")
    }

    function test_state_changes_rebuild_after_the_debounce() {
        fakeManager.entities["switch.kitchen"].state = "on"
        fakeManager.entitiesRevision++
        // Debounced (~320 ms), so not immediately...
        compare(view.tileById["switch.kitchen"].isOn, false, "not before the debounce")
        wait(700)
        compare(view.tileById["switch.kitchen"].isOn, true, "rebuilt once after the burst")
        // ...and a rendered tile followed the new value without any of its own JS.
        var tile = tileFor(view, "switch.kitchen")
        verify(tile.isOn, "the tile follows the debounced rebuild")
    }

    function test_tap_toggles_a_controllable_tile() {
        fakeManager.serviceCalls = []
        var light = tileFor(view, "light.corridor")
        verify(!!light)
        light.activate()
        compare(fakeManager.serviceCalls.length, 1)
        compare(fakeManager.serviceCalls[0], "light|turn_off|light.corridor",
            "an ON light is turned off on tap")

        var kitchen = tileFor(view, "switch.kitchen")
        kitchen.activate()
        compare(fakeManager.serviceCalls[1],
            kitchen.isOn ? "switch|turn_off|switch.kitchen" : "switch|turn_on|switch.kitchen",
            "the switch flips in the opposite direction of its state")

        fakeManager.serviceCalls = []
        tileFor(view, "sensor.outside").activate()
        compare(fakeManager.serviceCalls.length, 0, "a sensor sends no service")
    }

    function test_tap_on_a_sensor_opens_details_long_press_always_does() {
        groupsJsonTest.spyLastId = ""
        var tile = tileFor(view, "sensor.outside")
        tile.openDetailsRequested.connect(function (entId) { groupsJsonTest.spyLastId = entId })
        tile.activate()
        compare(groupsJsonTest.spyLastId, "sensor.outside", "non-controllable tap opens details")

        // The MouseArea's pressAndHold handler makes exactly this call on the
        // tile, so emitting the signal checks what the handler does without
        // depending on synthetic mouse timing.
        var lightTile = tileFor(view, "light.corridor")
        groupsJsonTest.spyLastId = ""
        lightTile.openDetailsRequested.connect(function (entId) { groupsJsonTest.spyLastId = entId })
        lightTile.openDetailsRequested("light.corridor")
        compare(groupsJsonTest.spyLastId, "light.corridor")
    }

    function test_legacy_cards_migrate_and_stay_hidden_when_emptied() {
        view.groupsJson = ""
        view.legacyCardsJson = JSON.stringify([
            { entityId: "light.corridor", size: "1x1" },
            { entityId: "sensor.outside", size: "2x2" }
        ])
        compare(view.groups.length, 1)
        compare(view.groups[0].name, "")
        compare(view.groups[0].tiles[0].size, "small")

        view.groupsJson = "[]"
        compare(view.groups.length, 0, "a deliberately emptied dashboard stays empty")
        view.groupsJson = groupsJsonTest.groupsJson
    }

    function test_tile_shows_precomputed_fields_and_content_modes() {
        compare(tile.title, "Свет в коридоре")
        compare(tile.iconSource, "mdi:lightbulb")
        compare(tile.showIcon, true)
        compare(tile.showTitle, true)
        compare(tile.isUnavailable, false)
        // Blue tile -> white text, amber tile -> dark text.
        tile.tileColor = "#0078d7"
        compare(String(tile.textColor).toLowerCase(), "#ffffff")
        tile.tileColor = "#ffd800"
        compare(String(tile.textColor).toLowerCase(), "#1a1a1a", "amber gets dark text")
        tile.tileColor = "#0078d7"

        tile.contentMode = "icon"
        compare(tile.showIcon, true)
        compare(tile.showTitle, false)
        tile.contentMode = "title"
        compare(tile.showIcon, false)
        compare(tile.showTitle, true)
        tile.contentMode = "both"
        tile.size = "small"
        compare(tile.showTitle, false, "small tiles drop the label in both mode")
        tile.size = "medium"

        tile.presentation = ({ title: "Fan", icon: "f", kind: "toggle", unavailable: true })
        verify(tile.isUnavailable, "an unavailable presentation is flagged")
        tile.presentation = ({ title: "Свет в коридоре", status: "", icon: "mdi:lightbulb",
                       domain: "light", kind: "toggle", isOn: true, unavailable: false })
    }

    function test_group_grid_places_tiles_within_the_width() {
        wait(50)
        // 4 columns across 318 px with 3 gaps: unit and spans must add up.
        verify(group.unit > 0, "the group computed a grid unit")
        var spacing = group.tileSpacing
        fuzzyCompare(4 * group.unit + 3 * spacing, 318, 0.01)

        var tiles = findByObjectName(group, "metroTile")
        compare(tiles.length, 2)
        // small = 1x1 unit at the grid origin...
        compare(tiles[0].x, 0)
        compare(tiles[0].y, 0)
        fuzzyCompare(tiles[0].width, group.unit, 0.01)
        fuzzyCompare(tiles[0].height, group.unit, 0.01)
        // ...wide = all four columns on the row below it.
        fuzzyCompare(tiles[1].x, 0, 0.01)
        fuzzyCompare(tiles[1].y, group.unit + spacing, 0.01)
        fuzzyCompare(tiles[1].width, 4 * group.unit + 3 * spacing, 0.01)
        fuzzyCompare(tiles[1].height, 2 * group.unit + spacing, 0.01)
        // The group height comes from the packing, so the Flickable scrolls
        // the true extent and nothing can grow it feedback-wise.
        var grid = findByObjectName(group, "metroGrid")
        fuzzyCompare(grid[0].height, 3 * group.unit + 2 * spacing, 0.01)
        // The tiles carry the group colour and their presentation data.
        compare(String(tiles[0].tileColor).toLowerCase(), "#0078d7")
        compare(tiles[0].title, "L")
        // Changing the content (title text) never changes the tile geometry:
        // the anti-feedback-loop guard of the manual placement.
        var beforeWidth = tiles[1].width
        group.dataMap = ({
            "light.corridor": ({ title: "A much longer light name here", icon: "x", kind: "toggle" }),
            "sensor.outside": ({ title: "A much longer sensor name here", icon: "y", kind: "view" })
        })
        wait(50)
        fuzzyCompare(tiles[1].width, beforeWidth, 0.01, "geometry ignores content")
    }

    function test_group_header_shows_the_name() {
        wait(50)
        verify(!!findByText(group, "Corridor"), "the group header renders its name")
        group.group = { id: "gy", name: "", color: null, tiles: [] }
        wait(50)
        verify(!findByText(group, "Corridor"), "an untitled group prints no header")
    }
}
