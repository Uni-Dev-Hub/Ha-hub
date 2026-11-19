import QtQuick
import QtTest
import "../../contents/l10n"
import "../../contents/ui/settings" as S

// The settings pages were the source of several runtime breakages (missing
// imports, filters wired to removed properties), so create them with data and
// let every delegate and binding evaluate.
TestCase {
    name: "SettingsPages"

    S.ConfigDashboard {
        id: dashboardPage
        width: 600
        height: 900
        visible: true
        cfg_dashboardColumns: 3
        cfg_dashboardTileContent: "both"
        cfg_dashboardCards: JSON.stringify([
            { entityId: "light.hall", size: "2x1" },
            { entityId: "cover.gate", size: "1x2" },
            { entityId: "switch.kitchen", size: "1x1" }
        ])
    }

    S.ConfigAppearance {
        id: appearancePage
        width: 600
        height: 700
        visible: true
        cfg_showDashboard: true
        cfg_showDevices: true
    }

    S.ConfigFavorites {
        id: favoritesPage
        width: 600
        height: 900
        visible: true
    }

    // findChild() only matches C++ class names, so walk the item tree and
    // look for the filter bar by one of its own properties.
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

    function test_1_dashboard_page_migrates_legacy_cards() {
        wait(150)
        // With no saved groups the v1.0 cards become one untitled group.
        compare(dashboardPage.groups.length, 1)
        compare(dashboardPage.groups[0].tiles.length, 3)
        compare(dashboardPage.totalTiles, 3)
        verify(dashboardPage.managerRef !== null, "preview keeps a manager reference")
        // Without a connection the picker stays empty but must not throw.
        compare(dashboardPage.availableEntities.length, 0)
        compare(Object.keys(dashboardPage.domainCounts).length, 0)
        // Titles fall back to the entity id when nothing is known about it.
        compare(dashboardPage.entityTitle("light.hall"), "light.hall")
        // Group options label the untitled group.
        compare(dashboardPage.groupOptions.length, 1)
        verify(dashboardPage.groupOptions[0].label.length > 0)
    }

    function test_2_dashboard_group_edits_persist() {
        var saved = function () {
            return JSON.parse(dashboardPage.cfg_dashboardGroups)
        }
        // The first add materialises the migrated model...
        dashboardPage.addEntity("sensor.outside")
        compare(saved().length, 1)
        compare(saved()[0].tiles.length, 4)
        // ...and the entity cannot be added twice.
        dashboardPage.addEntity("sensor.outside")
        compare(saved()[0].tiles.length, 4)

        // A second group receives the next tile once selected.
        dashboardPage.createGroup()
        compare(saved().length, 2)
        var freshId = saved()[1].id
        dashboardPage.activeGroupId = freshId
        dashboardPage.addEntity("fan.bedroom")
        compare(saved()[1].tiles.length, 1)
        compare(saved()[1].tiles[0].entityId, "fan.bedroom")

        dashboardPage.renameGroupById(freshId, "Night")
        compare(saved()[1].name, "Night")
        dashboardPage.colorGroup(freshId, "#FF0000")
        compare(saved()[1].color, "#ff0000")
        dashboardPage.colorGroup(freshId, "bogus")
        compare(saved()[1].color, null, "an invalid colour clears back to the accent")

        dashboardPage.sizeTile(freshId, "fan.bedroom", "large")
        compare(saved()[1].tiles[0].size, "large")
        dashboardPage.contentTile(freshId, "fan.bedroom", "icon")
        compare(saved()[1].tiles[0].content, "icon")
        dashboardPage.moveTileTo("fan.bedroom", saved()[0].id)
        compare(saved()[1].tiles.length, 0)
        compare(saved()[0].tiles.length, 5)

        dashboardPage.removeTileFrom(saved()[0].id, "fan.bedroom")
        compare(dashboardPage.totalTiles, 4)
        dashboardPage.deleteGroup(freshId)
        compare(saved().length, 1)
    }

    function test_favorites_page_renders_without_connection() {
        wait(150)
        compare(favoritesPage.filteredAllEntitiesList.length, 0)
        compare(favoritesPage.filteredFavEntitiesList.length, 0)
        compare(Object.keys(favoritesPage.domainCounts).length, 0)
        compare(favoritesPage.areaOptions.length, 0)
        // The shared filter bar drives both lists and exists on the page.
        var filter = findByProperty(favoritesPage, "selectedDomain")
        verify(!!filter, "favorites page has the shared filter bar")
        compare(filter.selectedDomain, "all")
        compare(filter.selectedArea, "all")
        compare(filter.searchText, "")
    }

    function test_filter_bar_lists_types_with_counts() {
        var filter = findByProperty(favoritesPage, "selectedDomain")
        filter.domainCounts = { cover: 2, light: 3 }
        compare(filter.totalCount, 5)
        // "All" plus one entry per domain, each with its count in the label.
        compare(filter.domainOptions.length, 3)
        compare(filter.domainOptions[0].id, "all")
        verify(filter.domainOptions[0].label.indexOf("5") !== -1)
        var coverIndex = filter.indexOfId(filter.domainOptions, "cover")
        verify(coverIndex > 0, "cover is listed")
        verify(filter.domainOptions[coverIndex].label.indexOf("cover (2)") === 0,
               "expected a counted label, got " + filter.domainOptions[coverIndex].label)
        // Unknown selection falls back to the first entry instead of -1.
        compare(filter.indexOfId(filter.domainOptions, "nope"), 0)
        filter.domainCounts = {}
    }

    function test_appearance_keeps_at_least_one_view() {
        wait(50)
        compare(appearancePage.enabledViewCount, 2)
        var dashboardCheck = findByText(appearancePage, Loc.t("Show 'Dashboard' tab"))
        var devicesCheck = findByText(appearancePage, Loc.t("Show 'Devices' tab"))
        verify(!!dashboardCheck && !!devicesCheck, "both view checkboxes exist")
        verify(dashboardCheck.enabled && devicesCheck.enabled, "both switchable while two views are on")

        appearancePage.cfg_showDevices = false
        compare(appearancePage.enabledViewCount, 1)
        verify(!dashboardCheck.enabled, "the last view cannot be switched off")
        verify(devicesCheck.enabled, "the hidden view can be switched back on")

        appearancePage.cfg_showDevices = true
        verify(dashboardCheck.enabled, "both switchable again")
    }

    function test_appearance_header_controls_without_connection() {
        wait(50)
        compare(appearancePage.headerPreviewText, "")
        // "Auto" plus one entry per known person: none while disconnected.
        compare(appearancePage.personChoice.length, 1)
        compare(appearancePage.personIndex, 0)

        var picker = findByProperty(appearancePage, "emptyText")
        verify(!!picker, "the header has an entity picker")
        verify(!picker.isSet, "no header entity selected by default")
        compare(picker.value, "")
        // Nothing to pick from without a connection.
        compare(picker.candidates.length, 0)
    }
}
