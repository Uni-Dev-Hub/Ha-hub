import QtQuick
import QtQuick.Layouts
import QtTest
import "../../contents/ui/views" as Views
import "../../contents/ui/components" as Components

// Metro dashboard: the view normalises its JSON model (including the legacy
// card migration) and the tiles resolve size, colours and content correctly.
TestCase {
    id: groupsJsonTest
    name: "DashboardGroups"

    QtObject {
        id: fakeManager
        property bool isConnected: true
        property int entitiesRevision: 1
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

    Components.MetroTile {
        id: tile
        width: 90
        height: 90
        visible: true
        haManager: fakeManager
        entityId: "light.corridor"
        size: "medium"
        contentMode: "both"
    }

    Components.DashboardGroup {
        id: group
        width: 318
        visible: true
        columns: 4
        haManager: fakeManager
        group: ({
            id: "gx", name: "Corridor", color: "#0078d7",
            tiles: [
                { entityId: "light.corridor", size: "small", content: "" },
                { entityId: "sensor.outside", size: "wide", content: "" }
            ]
        })
    }

    function findByProperty(item, property) {
        if (!item) return null
        if (item[property] !== undefined) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var found = findByProperty(kids[i], property)
            if (found) return found
        }
        return null
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

    function test_view_model_skips_empty_groups() {
        wait(100)
        compare(view.groups.length, 2, "the tile-less group is hidden")
        compare(view.groups[0].tiles.length, 3)
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

    function test_tile_resolves_title_icon_and_contrast() {
        wait(50)
        compare(tile.title, "Свет в коридоре", "catalog name wins")
        compare(tile.iconSource, "mdi:lightbulb")
        compare(tile.showIcon, true)
        compare(tile.showTitle, true)
        // Blue tile → white text, amber tile → dark text.
        tile.tileColor = "#0078d7"
        compare(String(tile.textColor).toLowerCase(), "#ffffff")
        tile.tileColor = "#ffd800"
        compare(String(tile.textColor).toLowerCase(), "#1a1a1a", "amber gets dark text")
        tile.tileColor = "#0078d7"
    }

    function test_tile_content_modes_and_small_tiles() {
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

        tile.entityId = "fan.bedroom"
        verify(tile.isUnavailable, "an unavailable entity is flagged")
        tile.entityId = "light.corridor"
    }

    function test_group_grid_fits_the_width() {
        wait(50)
        // 4 columns across 318 px with 3 gaps: unit and spans must add up.
        verify(group.unit > 0, "the group computed a grid unit")
        var spacing = group.tileSpacing
        fuzzyCompare(4 * group.unit + 3 * spacing, 318, 0.01)

        var tiles = []
        function collect(item) {
            if (!item) return
            if (item.objectName === "metroTile") tiles.push(item)
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++) collect(kids[i])
        }
        collect(group)
        compare(tiles.length, 2)
        // small = 1x1 units, wide = all four columns.
        fuzzyCompare(tiles[0].Layout.preferredWidth, group.unit, 0.01)
        fuzzyCompare(tiles[1].Layout.preferredWidth, 4 * group.unit + 3 * spacing, 0.01)
        fuzzyCompare(tiles[1].Layout.preferredHeight, 2 * group.unit + spacing, 0.01)
        // The tiles carry the group colour.
        compare(String(tiles[0].tileColor).toLowerCase(), "#0078d7")
    }

    function test_group_header_shows_the_name() {
        wait(50)
        verify(!!findByText(group, "Corridor"), "the group header renders its name")
        group.group = { id: "gy", name: "", color: null, tiles: [] }
        wait(50)
        verify(!findByText(group, "Corridor"), "an untitled group prints no header")
    }
}
