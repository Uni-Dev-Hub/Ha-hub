import QtQuick
import QtTest
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
        cfg_showDashboard: true
        cfg_dashboardColumns: 3
        cfg_dashboardCardSize: "normal"
        cfg_dashboardCards: JSON.stringify([
            { entityId: "light.hall", size: "2x1" },
            { entityId: "cover.gate", size: "1x2" },
            { entityId: "switch.kitchen", size: "1x1" }
        ])
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

    function test_dashboard_page_renders_card_rows() {
        wait(150)
        compare(dashboardPage.cards.length, 3)
        verify(dashboardPage.managerRef !== null, "preview keeps a manager reference")
        // Without a connection the picker stays empty but must not throw.
        compare(dashboardPage.availableEntities.length, 0)
        compare(Object.keys(dashboardPage.domainCounts).length, 0)
        // Titles fall back to the entity id when nothing is known about it.
        compare(dashboardPage.entityTitle("light.hall"), "light.hall")
    }

    function test_dashboard_card_edits_persist() {
        dashboardPage.addCard("light.hall")   // already present: ignored
        compare(dashboardPage.cards.length, 3)
        dashboardPage.addCard("sensor.outside")
        compare(dashboardPage.cards.length, 4)
        dashboardPage.setCardSize(3, "2x2")
        compare(JSON.parse(dashboardPage.cfg_dashboardCards)[3].size, "2x2")
        dashboardPage.moveCard(3, -1)
        compare(JSON.parse(dashboardPage.cfg_dashboardCards)[2].entityId, "sensor.outside")
        dashboardPage.removeCard(2)
        compare(dashboardPage.cards.length, 3)
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
}
