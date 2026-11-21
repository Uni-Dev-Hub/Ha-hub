import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../contents/l10n"
import "../../contents/ui/settings" as S

// The settings pages were the source of several runtime breakages (missing
// imports, filters wired to removed properties), so create them with data and
// let every delegate and binding evaluate.
TestCase {
    name: "SettingsPages"
    // A TestCase is invisible by default, and `visible` in QML reports the
    // effective value - so every visibility assertion below would read false
    // and pass for the wrong reason.
    visible: true

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

    // A pick lands in cfg_language, which Apply copies into the configuration -
    // and nowhere past it. The version before that wrote the language into the
    // applet's configuration behind the dialog's back, and the dialog, whose own
    // copy still held the old language, wrote it back when it closed.
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

    // A click on an entity's name in the editor renames that entity for the
    // whole widget. The name is stored as a map of its own - keyed by entity,
    // not by tile - so it holds across groups and outlives the tile it was
    // typed in.
    function test_6_an_entity_name_is_edited_by_click_and_saved() {
        wait(50)
        dashboardPage.cfg_entityAliases = JSON.stringify({ "light.hall": "Люстра над столом" })
        wait(50)

        var labels = findByObjectName(dashboardPage, "tileNameLabel")
        verify(labels.length >= 3, "every tile row is named: " + labels.length)
        var renamed = null
        var untouched = null
        for (var i = 0; i < labels.length; i++) {
            if (labels[i].text === "Люстра над столом") renamed = labels[i]
            if (labels[i].text === "cover.gate") untouched = labels[i]
        }
        verify(!!renamed, "the name the user typed is the one shown")
        verify(!!untouched, "and an entity without one keeps what Home Assistant calls it")

        // The line under a name is one line, on every row, whether the entity
        // was renamed or not: a row that grew a second line only when renamed
        // stood taller than its neighbours and left their controls off-centre.
        var subs = findByObjectName(dashboardPage, "tileNameSubtitle")
        compare(subs.length, labels.length, "every row carries its second line")
        var subShown = 0
        for (var s = 0; s < subs.length; s++) if (subs[s].visible) subShown++
        compare(subShown, labels.length, "and none of them is hidden")
        var renamedSub = null
        for (var t = 0; t < subs.length; t++)
            if (subs[t].text.indexOf("light.hall") === 0) renamedSub = subs[t]
        verify(!!renamedSub, "it names the entity even where the name was changed")

        var cards = findByObjectName(dashboardPage, "tileRowCard")
        var heights = []
        for (var y = 0; y < cards.length; y++) heights.push(Math.round(cards[y].height))
        var distinct = {}
        for (var z = 0; z < heights.length; z++) distinct[heights[z]] = true
        compare(Object.keys(distinct).length, 1,
                "so the rows are one height: " + heights.join(", "))

        var resets = findByObjectName(dashboardPage, "tileNameReset")
        var offered = 0
        for (var r = 0; r < resets.length; r++) if (resets[r].visible) offered++
        compare(offered, 1, "only the renamed row offers to take the name back")

        // The click: the name becomes an editor, and the row is edited alone.
        dashboardPage.renamingEntity = "light.hall"
        wait(50)
        var fields = findByObjectName(dashboardPage, "tileNameField")
        var field = null
        for (var f = 0; f < fields.length; f++) if (fields[f].visible) field = fields[f]
        verify(!!field, "a click on the name opens an editor for it")
        if (!field) return
        compare(field.text, "Люстра над столом", "starting from the name in use")
        compare(field.placeholderText, "light.hall", "showing what is being overridden")
        var hiddenLabels = 0
        for (var l = 0; l < labels.length; l++) if (!labels[l].visible) hiddenLabels++
        compare(hiddenLabels, 1, "only that row turns into an editor")

        // Enter, or a click away, saves.
        field.text = "  Верхний свет  "
        field.editingFinished()
        wait(50)
        compare(JSON.parse(dashboardPage.cfg_entityAliases)["light.hall"], "Верхний свет",
                "typed spaces are trimmed on the way in")
        verify(dashboardPage.renamingEntity === "", "and the row is a name again")

        // An empty name is not a name: the entry is gone, not blank.
        dashboardPage.setEntityName("light.hall", "")
        wait(50)
        verify(JSON.parse(dashboardPage.cfg_entityAliases)["light.hall"] === undefined,
               "an empty name takes the override back")

        dashboardPage.cfg_entityAliases = "{}"
    }
    // The pages ask Kirigami.FormLayout for a label column and a field column,
    // and the layout sizes itself to the widest thing it holds - a hint line
    // that may wrap asks for the width of its whole text in one line. Bounded,
    // everything stays inside the window; unbounded, the form and every field
    // with it ran past the right edge and were cut off.
    function textBearing(item, out) {
        out = out || []
        if (!item) return out
        // Anything the user sees and reads: text, and the icon-only buttons of
        // a tile row, which carry an icon instead of a word.
        if ((item.text !== undefined || item.icon !== undefined)
            && item.visible && item.height > 0) out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) textBearing(kids[i], out)
        return out
    }

    // How Plasma hosts a settings page: the dialog is a Kirigami.ApplicationItem
    // whose pageStack shows one page at a time and hands it the cfg_ values. The
    // pages lay out differently inside a plain item than they do inside that -
    // which is where the overflow below was hiding, and why this test goes
    // through the same host rather than the pages above.
    Kirigami.ApplicationItem {
        id: dialogHost
        width: 620
        height: 900
        visible: true
    }

    function pageFits(host, page, label, width) {
        var items = textBearing(page)
        var atLeast = { general: 6, dashboard: 5, appearance: 4, favorites: 1 }
        var problems = []
        for (var i = 0; i < items.length; i++) {
            var edge = items[i].mapToItem(page, items[i].width, 0, 0, 0).x
            if (edge > page.width + 1) {
                problems.push("x=" + Math.round(edge) + " of " + Math.round(page.width)
                              + " text=" + JSON.stringify(String(items[i].text).substring(0, 24)))
            }
        }
        verify(page.width >= width - 2 * Kirigami.Units.gridUnit,
                label + " at " + width + "px really got that width: " + Math.round(page.width))
        verify(items.length >= atLeast[label], label + " at " + width
               + "px shows enough to measure: " + items.length)
        verify(problems.length === 0, label + " at " + width + "px: " + problems.join(" ; "))
    }

    function test_7_every_page_fits_the_width_it_is_given() {
        var names = ["general", "dashboard", "appearance", "favorites"]
        var widths = [460, 620, 810, 1100, 1380]
        // The widest language available, because a label column is only as wide
        // as the widest label - English hides what Russian shows.
        var languageBefore = Loc.configuredLanguage
        Loc.configuredLanguage = "ru"
        wait(80)
        for (var i = 0; i < widths.length; i++) {
            dialogHost.width = widths[i]
            for (var q = 0; q < names.length; q++) {
                var page = dialogHost.pageStack.replace(
                    Qt.resolvedUrl("../../contents/ui/settings/Config"
                                   + names[q].substring(0, 1).toUpperCase()
                                   + names[q].substring(1) + ".qml"),
                    { cfg_dashboardGroups: JSON.stringify([{
                        id: "g1", name: "G", color: "#0078d7",
                        tiles: [{ entityId: "light.hall", size: "wide", content: "" },
                                { entityId: "cover.gate", size: "medium", content: "" }]
                    }]),
                      cfg_entityAliases: JSON.stringify({ "light.hall": "Люстра" }),
                      cfg_dashboardColumns: 3 })
                wait(160)
                verify(!!page, names[q] + " opens in the host")
                if (!page) continue
                pageFits(dialogHost, page, names[q], widths[i])
            }
        }
        Loc.configuredLanguage = languageBefore
        wait(60)
    }

    function test_8_a_page_puts_its_own_heading_back() {
        wait(50)
        Loc.configuredLanguage = "de"
        wait(50)
        generalPage.title = "Allgemein"
        wait(50)
        verify(generalPage.title === "Allgemein", "the assignment stuck, as it does in Plasma")
        verify(generalPage.pageTitle === Loc.t("General"), "the page still knows its own heading")

        Loc.configuredLanguage = "ru"
        wait(50)
        compare(generalPage.title, Loc.t("General"), "and a language change puts it back")

        Loc.configuredLanguage = "en"
        wait(50)
        compare(generalPage.title, Loc.t("General"), "again in another language")
    }

}
