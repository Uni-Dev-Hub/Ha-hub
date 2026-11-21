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

    S.ConfigGeneral {
        id: generalPage
        width: 600
        height: 800
        visible: true
        cfg_language: "en"
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
        compare(saved()[1].tiles[0].size, "wide", "the retired large size folds into wide")
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

    function findByObjectName(item, name, out) {
        out = out || []
        if (!item) return out
        if (item.objectName === name) out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) findByObjectName(item.children[i], name, out)
        return out
    }

    function itemTreeContains(item, target) {
        if (!item) return false
        if (item === target) return true
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++)
            if (itemTreeContains(item.children[i], target)) return true
        return false
    }

    // What a dialog holds is not under its `children`: Kirigami puts the content
    // behind a ScrollView inside the popup's own item, and that item is not the
    // dialog's child either. `dialogChildren` is the handle on the declared
    // content, `contentItem` on the item a plain Controls.Dialog shows.
    function holdsItem(dialog, target) {
        var roots = [dialog.contentItem].concat(dialog.dialogChildren || [])
        for (var i = 0; i < roots.length; i++)
            if (itemTreeContains(roots[i], target)) return true
        return false
    }

    // The picker hands the language to the configuration straight away. It used
    // to wait for Apply, and that round trip could hand back the page's
    // declared "system" default - which KConfig then dropped from the file, so
    // leaving the settings undid the choice.
    //
    // Driven through the controls, not through the page's function: the version
    // that shipped broken assigned to the read-only popup.closed inside the
    // delegate, and a test calling selectLanguage() directly stayed green while
    // every real click threw.
    function test_3_language_picker_applies_and_saves() {
        wait(50)
        var combo = findByObjectName(generalPage, "languageCombo")
        compare(combo.length, 1, "the language picker exists")
        if (combo.length === 0) return
        combo = combo[0]
        compare(combo.currentIndex, combo.indexForCode("en"), "and starts on the configured language")
        verify(combo.entries === combo.entries, "the picker has a model")

        var modelBefore = combo.entries
        var german = combo.indexForCode("de")

        // A click on the list, the way a user picks. The popup has to be told
        // its height here: a closed popup has never realized its delegates.
        combo.popup.height = 320
        combo.popup.contentHeight = 320
        combo.popup.open()
        wait(200)
        var row = combo.popup.contentItem ? combo.popup.contentItem.itemAtIndex(german) : null
        verify(!!row, "the popup builds its rows")
        if (row) {
            compare(row.text, combo.labelFor("de"), "the row is named by its own speakers")
            row.clicked()
            wait(50)
            compare(generalPage.cfg_language, "de", "the click reaches the language")
            compare(Loc.configuredLanguage, "de", "without waiting for Apply")
            compare(Loc.language, "de", "and the interface follows at once")
            verify(!combo.popup.visible, "and the list closes after the pick")
        }

        combo.currentIndex = combo.indexForCode("en")
        generalPage.cfg_language = "en"
        Loc.configuredLanguage = "en"
        wait(50)

        // Keyboard navigation: the popup moves currentIndex and emits activated.
        combo.activated(combo.indexForCode("de"))
        wait(50)
        compare(generalPage.cfg_language, "de", "activated() picks too")
        compare(Loc.language, "de")
        verify(combo.displayText === combo.labelFor("de"),
               "the button shows the language's own name: " + combo.displayText)

        // The model survives the switch: the same array, so the control never
        // rebuilds its list - and never resets currentIndex - under a pick. A
        // translated string inside the model would do exactly that.
        verify(combo.entries === modelBefore, "the language switch does not rebuild the model")
        compare(combo.count, 1 + Loc.languages.length, "system plus every language")
        for (var i = 0; i < Loc.languages.length; ++i) {
            var code = Loc.languages[i].code
            // The delegates print labelFor(code), so this is the list content.
            verify(combo.labelFor(code) === Loc.languages[i].label, code + " names itself natively")
        }
        verify(combo.labelFor("system") === Loc.t("System language"), "and the system row is translated")

        generalPage.selectLanguage("system")
        wait(50)
        compare(Loc.configuredLanguage, "system", "the system language can be taken back")
        compare(Loc.language, Loc.systemLanguage)
        verify(combo.displayText === combo.labelFor("system"),
               "the button keeps the translated label: " + combo.displayText)
    }

    // The grid packs any column count, so the picker must offer them: 5 was
    // missing, and a saved count the list does not offer would leave the combo
    // showing its first entry while the configuration kept the real one.
    function test_4_grid_columns_are_selectable() {
        wait(50)
        var combos = findByObjectName(dashboardPage, "columnsCombo")
        compare(combos.length, 1, "the columns picker exists")
        if (combos.length === 0) return
        var combo = combos[0]

        compare(combo.model.indexOf(5) !== -1, true, "5 columns can be chosen")
        for (var i = 0; i < combo.model.length; ++i)
            verify(combo.model[i] >= 2, "the list holds real column counts")

        dashboardPage.cfg_dashboardColumns = 5
        wait(50)
        compare(combo.currentIndex, combo.model.indexOf(5), "5 is shown as the current choice")

        // A number, not the string the control prints: the cfg property is an int.
        combo.activated(combo.model.indexOf(4))
        wait(50)
        compare(dashboardPage.cfg_dashboardColumns, 4)
        verify(typeof dashboardPage.cfg_dashboardColumns === "number", "stored as a number")

        // A saved count outside the list stays visible instead of lying.
        dashboardPage.cfg_dashboardColumns = 7
        wait(50)
        compare(combo.model.indexOf(7) !== -1, true, "an unusual saved count is offered too")
        compare(combo.currentIndex, combo.model.indexOf(7), "and is the one displayed")
        dashboardPage.cfg_dashboardColumns = 5
    }

    // The tray icon picker used to be a Popup anchored to Overlay.overlay from
    // its own scope, which placed it over the settings dialog's header and
    // dimmed a dialog that was already modal. It is a Kirigami.Dialog now.
    function test_5_tray_icon_picker_is_a_dialog() {
        wait(50)
        var fields = findByObjectName(appearancePage, "trayIconField")
        compare(fields.length, 1, "the tray icon field is there")
        if (fields.length === 0) return
        var dialog = fields[0].pickerDialog
        verify(!!dialog, "and it exposes the dialog it opens")
        if (!dialog) return

        verify(!dialog.visible, "and starts closed")
        dialog.open()
        wait(200)
        verify(dialog.visible, "it opens")
        verify(dialog.height > 0 && dialog.width > 0,
               "and is sized: " + Math.round(dialog.width) + "x" + Math.round(dialog.height))

        // The grid of icons is what the dialog exists for. Kirigami.Dialog keeps
        // its content behind a ScrollView inside the popup's own item, so
        // `children` and `parent` never lead between the two; `dialogChildren`
        // is the documented handle on what the dialog holds.
        var grid = fields[0].pickerGrid
        verify(!!grid, "and it exposes the icon grid")
        if (!grid) return
        verify(holdsItem(dialog, grid), "and that grid belongs to the dialog")
        verify(grid.count > 0, "the grid has icons to pick: " + grid.count)

        dialog.close()
        wait(200)
        // `visible` only drops once the fade-out finished; `opened` is the state
        // the control itself tracks and what `open()` above set.
        verify(!dialog.opened, "and closes again")
    }
}
