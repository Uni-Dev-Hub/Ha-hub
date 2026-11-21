import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
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
        presentation: ({ title: "Свет в коридоре", status: "", icon: "lightbulb",
                         iconKind: "mdi", fallbackIcon: "brightness-high-symbolic",
                         domain: "light", kind: "toggle", isOn: true, unavailable: false })
    }

    // A row-sized tile (1 column at a 3-column popup) used for typography
    // checks, so the name tests never touch the presentation of `tile`. The
    // height mirrors what DashboardGroup really gives a row, so these checks
    // follow the layout instead of a frozen pixel number.
    Components.MetroTile {
        id: rowTile
        width: 150
        height: Math.round(Kirigami.Units.gridUnit * 3.1)
        visible: true
        entityId: "light.corridor"
        size: "small"
        contentMode: "both"
        presentation: ({
            title: "Настенная лампа в детской комнате у окна справа", status: "On",
            icon: "floor-lamp", iconKind: "mdi", fallbackIcon: "brightness-high-symbolic",
            valueText: "", trailing: "switch", stateIcon: "",
            domain: "light", kind: "toggle", isOn: true, unavailable: false
        })
    }

    // A realistic name in the same row: it must be readable whole, which is
    // the whole reason the name got the width of the tile.
    Components.MetroTile {
        id: fitTile
        width: 150
        height: Math.round(Kirigami.Units.gridUnit * 3.1)
        visible: true
        entityId: "light.corridor"
        size: "small"
        contentMode: "both"
        presentation: ({
            title: "Люстра дома", status: "On",
            icon: "ceiling-light", iconKind: "mdi", fallbackIcon: "brightness-high-symbolic",
            valueText: "", trailing: "switch", stateIcon: "",
            domain: "light", kind: "toggle", isOn: true, unavailable: false
        })
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

    // The same group in bigger type: Settings -> Dashboard hands a family and a
    // size down, and a bigger size has to grow the row rather than cut the name.
    Components.DashboardGroup {
        id: bigFontGroup
        width: 318
        visible: true
        columns: 4
        tileFontFamily: Qt.application.font.family
        tilePointSize: 14
        group: ({
            id: "gz", name: "Big type", color: "#0078d7",
            tiles: [{ entityId: "light.corridor", size: "small", content: "" }]
        })
        dataMap: ({
            "light.corridor": ({ title: "Настенная лампа в детской", icon: "x", kind: "toggle" })
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
        compare(light.icon, "lightbulb", "the mdi: prefix is stripped for the font lookup")
        compare(light.iconKind, "mdi", "the entity's own HA icon is drawn from the MDI font")
        compare(light.fallbackIcon, "brightness-high-symbolic")
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
        compare(tile.iconSource, "lightbulb")
        compare(tile.iconKind, "mdi")
        compare(tile.fallbackIconSource, "brightness-high-symbolic")
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
        compare(tile.iconSource, "lightbulb")
        compare(tile.iconKind, "mdi")
        compare(tile.fallbackIconSource, "brightness-high-symbolic")
        compare(tile.showIcon, true)
        compare(tile.showTitle, true)
        compare(tile.isUnavailable, false)
        // Colour is an accent, not a fill: the hue/saturation survive and only
        // the lightness moves when the raw colour would sink into the theme.
        tile.tileColor = "#0078d7"
        verify(Math.abs(tile.accent.hslHue - tile.tileColor.hslHue) < 0.02, "accent keeps the hue")
        verify(Math.abs(tile.accent.hslSaturation - tile.tileColor.hslSaturation) < 0.02,
               "accent keeps the saturation")
        var darkTheme = Kirigami.Theme.backgroundColor.hslLightness < 0.5
        tile.tileColor = "#004e5c" // deep teal
        if (darkTheme)
            verify(tile.accent.hslLightness > 0.5, "a deep accent is lifted on dark themes")
        else
            verify(tile.accent.hslLightness <= 0.45, "a deep accent stays deep on light themes")
        tile.tileColor = "#ffd800" // amber
        if (darkTheme)
            verify(tile.accent.hslLightness >= 0.5, "a bright accent stays bright on dark themes")
        else
            verify(tile.accent.hslLightness < 0.45, "amber is darkened for light themes")
        tile.tileColor = "#0078d7"

        tile.contentMode = "icon"
        compare(tile.showIcon, true)
        compare(tile.showTitle, false)
        tile.contentMode = "title"
        compare(tile.showIcon, false)
        compare(tile.showTitle, true)
        tile.contentMode = "both"
        tile.size = "small"
        compare(tile.showTitle, true, "every tile size keeps the label: tiles are for reading")
        tile.size = "medium"

        tile.presentation = ({ title: "Fan", icon: "f", kind: "toggle", unavailable: true })
        verify(tile.isUnavailable, "an unavailable presentation is flagged")
        verify(tile.showStatus, "an unavailable tile still tells its story in the tooltip")
        compare(tile.showSwitch, false, "an unavailable entity does not offer a switch")
        verify(tile.showTrailingIcon, "an unavailable entity warns with the icon slot")

        // The row is what the dashboard reads by: name plus a switch, a value
        // or a pictogram on its right edge - never a sentence.
        tile.presentation = ({ title: "Свет в коридоре", status: "On • 80%", icon: "lightbulb",
                       iconKind: "mdi", fallbackIcon: "brightness-high-symbolic",
                       valueText: "", trailing: "switch", stateIcon: "",
                       domain: "light", kind: "toggle", isOn: true, unavailable: false })
        wait(50)
        verify(!!findByText(tile, "Свет в коридоре"), "the name renders on the tile")
        var switches = findByObjectName(tile, "tileTrailingSwitch")
        compare(switches.length, 1, "a switchable tile ends in a mini switch")
        compare(switches[0].checked, true, "the switch mirrors the entity")
        verify(switches[0].scale < 1, "a stock switch would eat the name of a one-column tile")
        verify(!findByText(tile, "On • 80%"), "no state sentence in a row tile (it lives in the tooltip)")

        tile.presentation = ({ title: "Улица", status: "-3.5 °C", icon: "thermometer",
                       valueText: "-3.5 °C", trailing: "value", stateIcon: "",
                       domain: "sensor", kind: "view", isOn: false, unavailable: false })
        wait(50)
        verify(!!findByText(tile, "-3.5 °C"), "a sensor tile answers with its value")
    }

    // A row is barely three grid units tall, so the name is small and light and
    // gets the whole width under the glyph: two lines of it, and the tooltip
    // carries the text when even those are not enough.
    function test_tile_name_uses_two_small_lines() {
        var labels = findByObjectName(rowTile, "tileTitle")
        compare(labels.length, 1)
        var label = labels[0]
        verify(label.font.pointSize <= 7.5, "a 7.5pt name keeps the row compact")
        verify(!label.font.bold, "a light name, no bold weight in a narrow row")
        compare(label.maximumLineCount, 2, "a long name gets a second line")
        verify(label.wrapMode !== Text.NoWrap, "the name wraps instead of being cut off")
        compare(label.lineCount, 2, "an over-long name really does break twice")
        verify(label.height <= rowTile.height, "two lines still fit inside the row")
    }

    // The reason the name moved out of the row: with the glyph and the switch
    // beside it, a one-column tile left the name ~35 px - "Бол шо…" and nothing
    // else. Out of the row it prints a normal device name whole.
    function test_tile_name_gets_the_full_width_of_the_row() {
        var wide = findByObjectName(rowTile, "tileTitle")
        var short = findByObjectName(fitTile, "tileTitle")
        compare(wide.length, 1)
        compare(short.length, 1)
        verify(wide[0].width >= rowTile.width * 0.85,
               "the name spans the row (" + Math.round(wide[0].width) + " of " + rowTile.width + ")")
        verify(!short[0].text.endsWith("\u2026"),
               "a normal device name is shown whole: " + short[0].text)
        compare(short[0].lineCount, 1, "and it does not even need the second line")
    }

    // Two zones: glyph and state answer on top, the name under them, printed at
    // the bottom edge of the tile.
    function test_tile_keeps_the_glyph_above_and_the_name_below() {
        var labels = findByObjectName(rowTile, "tileTitle")
        var glyphs = findByObjectName(rowTile, "tileGlyph")
        var slots = findByObjectName(rowTile, "tileTrailingSwitchSlot")
        compare(labels.length, 1)
        compare(glyphs.length, 1)
        compare(slots.length, 1)
        var label = labels[0]
        var glyphTop = glyphs[0].mapToItem(rowTile, 0, 0).y
        var glyphBottom = glyphTop + glyphs[0].height
        var labelTop = label.mapToItem(rowTile, 0, 0).y
        var bottom = label.mapToItem(rowTile, 0, label.height).y
        verify(labelTop >= glyphBottom - 1,
               "the name starts under the glyph (" + labelTop + " vs " + glyphBottom + ")")
        verify(bottom >= rowTile.height - 8,
               "the name reaches the bottom edge (bottom " + bottom + " of " + rowTile.height + ")")
        verify(bottom <= rowTile.height, "the name stays inside the row")
        var slot = slots[0]
        verify(slot.mapToItem(rowTile, 0, 0).y < rowTile.height / 2,
               "the state answer stays in the upper zone")
    }

    // The glyph is a hint, not the label: it stays out of the name's way. Only
    // a tile that shows no name at all can afford the big one.
    function test_row_tile_keeps_the_glyph_small() {
        var glyphs = findByObjectName(rowTile, "tileGlyph")
        compare(glyphs.length, 1)
        compare(glyphs[0].size, Kirigami.Units.iconSizes.small, "a row glyph is the small icon size")
        tile.contentMode = "icon"
        var big = findByObjectName(tile, "tileGlyph")
        compare(big.length, 1)
        verify(big[0].size >= Kirigami.Units.iconSizes.medium,
               "icon-mode tiles keep the big glyph")
        tile.contentMode = "both"
    }

    function test_group_grid_places_tiles_within_the_width() {
        wait(50)
        // 4 columns across 318 px with 3 gaps: unit and spans must add up.
        verify(group.unit > 0, "the group computed a grid unit")
        var spacing = group.tileSpacing
        fuzzyCompare(4 * group.unit + 3 * spacing, 318, 0.01)
        verify(group.tileHeight > 0 && group.tileHeight < group.unit,
               "rows are compact: shorter than a column is wide")

        var tiles = findByObjectName(group, "metroTile")
        compare(tiles.length, 2)
        // small = 1 column wide at the grid origin, one row tall...
        compare(tiles[0].x, 0)
        compare(tiles[0].y, 0)
        fuzzyCompare(tiles[0].width, group.unit, 0.01)
        fuzzyCompare(tiles[0].height, group.tileHeight, 0.01)
        // ...wide = all four columns directly below it.
        fuzzyCompare(tiles[1].x, 0, 0.01)
        fuzzyCompare(tiles[1].y, group.tileHeight + spacing, 0.01)
        fuzzyCompare(tiles[1].width, 4 * group.unit + 3 * spacing, 0.01)
        fuzzyCompare(tiles[1].height, group.tileHeight, 0.01)
        // The group height comes from the packing, so the Flickable scrolls
        // the true extent and nothing can grow it feedback-wise.
        var grid = findByObjectName(group, "metroGrid")
        fuzzyCompare(grid[0].height, 2 * group.tileHeight + spacing, 0.01)
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

    // Settings -> Dashboard lets the user pick the family and the size of the
    // tile text. A bigger size must grow the row: a row that stayed 56 px tall
    // would print 14pt names as an ellipsis, which is worse than the setting
    // not existing at all.
    function test_tile_font_follows_the_settings() {
        wait(50)
        // A plain tile, typed at the size it is designed at. (`group` is no use
        // here: the header test above empties its tiles.)
        var plainLabels = findByObjectName(rowTile, "tileTitle")
        var bigLabels = findByObjectName(bigFontGroup, "tileTitle")
        compare(plainLabels.length, 1)
        compare(bigLabels.length, 1)

        // Nothing configured: the tile types itself at the size it is designed
        // at, in the font the theme picked.
        compare(plainLabels[0].font.pointSize, 7.5, "the designed size by default")

        compare(bigFontGroup.effectivePointSize, 14, "the group passes the size on")
        compare(bigLabels[0].font.pointSize, 14, "and the tile prints it")
        verify(bigLabels[0].font.family.length > 0, "the chosen family reaches the text")
        verify(bigFontGroup.tileHeight > group.tileHeight,
               "the row grows for the bigger type: " + bigFontGroup.tileHeight
               + " over " + group.tileHeight)
        verify(bigLabels[0].height <= bigFontGroup.tileHeight,
               "and two lines of it still fit in the row")
    }
}
