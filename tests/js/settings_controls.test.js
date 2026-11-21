const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.join(__dirname, "..", "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");
const pages = [
    "contents/ui/settings/ConfigGeneral.qml",
    "contents/ui/settings/ConfigDashboard.qml",
    "contents/ui/settings/ConfigFavorites.qml",
    "contents/ui/settings/ConfigAppearance.qml",
];

// QtQuick Controls marks several of Popup's state properties read-only, and an
// assignment there does not fail quietly: it throws a TypeError that aborts the
// handler it lives in. One settings picker lost every mouse click that way -
// the list opened, the row highlighted, nothing ever happened.
test("settings controls never write to a read-only property", () => {
    for (const file of pages) {
        const source = read(file);
        assert.doesNotMatch(source, /popup\.closed\s*=/, file + " assigns to the read-only popup.closed");
        assert.doesNotMatch(source, /popup\.visible\s*=/, file + " assigns to the read-only popup.visible");
        assert.doesNotMatch(source, /popup\.opened\s*=/, file + " assigns to the read-only popup.opened");
    }
});

// Signal handlers that rely on injected parameters only work by an old
// convenience: the value is not passed, it is looked up in the scope. Plasma
// warns about it, and the lookup is exactly what breaks under
// `pragma ComponentBehavior: Bound`.
test("signal handlers take their parameters formally", () => {
    for (const file of pages) {
        const source = read(file);
        for (const match of source.matchAll(/onActivated:\s*(.+)/g)) {
            if (!/\bindex\b/.test(match[1])) continue;
            assert.match(match[1], /^\(\s*index\s*\)\s*=>/,
                file + " relies on an injected `index` instead of a formal parameter");
        }
    }
});

// The dashboard grid packs any column count - the preview in this very page
// uses five - so the picker has to offer them. A saved count the list does not
// contain used to leave the combo showing its first entry while the
// configuration quietly kept the real one.
test("the grid columns picker offers every count the grid can pack", () => {
    const dashboard = read("contents/ui/settings/ConfigDashboard.qml");
    const combo = dashboard.match(/Controls\.ComboBox \{\s*\n\s*id: columnsCombo[\s\S]*?\n {12}\}/);
    assert.ok(combo, "the columns combo is there");
    const counts = combo[0].match(/readonly property var counts:\s*\[([\d,\s]+)\]/);
    assert.ok(counts, "the offered counts are listed in one place");
    const offered = counts[1].split(",").map(s => Number(s.trim())).filter(n => !Number.isNaN(n));
    for (const n of [2, 3, 4, 5, 6]) {
        assert.ok(offered.indexOf(n) !== -1, n + " columns must be offered");
    }
    assert.match(combo[0], /onActivated:\s*\(index\)\s*=>/, "the pick uses the index the signal carries");
    assert.match(combo[0], /Number\(model\[index\]\)/, "and stores a number, not the text the control prints");
    assert.match(combo[0], /objectName:\s*"columnsCombo"/, "so a test can find it");
});

// Anchoring a Popup to the overlay from inside its own scope, and forcing it
// modal inside a dialog that is already modal, made the tray icon picker land
// over the settings dialog's header, half outside it. Kirigami.Dialog places
// and modals itself, and Plasma's own configuration dialog uses it.
test("the tray icon picker is a dialog, not an overlay-anchored popup", () => {
    const field = read("contents/ui/components/IconPickerField.qml");
    assert.match(field, /Kirigami\.Dialog\s*\{/, "the picker is a Kirigami.Dialog");
    assert.doesNotMatch(field, /parent:\s*[\w.]*Overlay\.overlay/, "nothing is parented to the overlay by hand");
    assert.doesNotMatch(field, /anchors\.centerIn:\s*[\w.]*Overlay\.overlay/, "nothing is anchored to the overlay by hand");
    assert.match(field, /objectName:\s*"trayIconDialog"/, "and a test can find it");
});

// The tile type used to be two hard-coded 7.5pt numbers in the tile itself, so
// a user who wanted readable names had no way to ask for them. The choice now
// lives in Settings -> Dashboard and reaches every tile through the view, so
// the page, the configuration and the tile have to agree on the same keys.
test("the dashboard font is a setting, not a number baked into the tile", () => {
    const config = read("contents/config/main.xml");
    assert.match(config, /<entry name="dashboardFontFamily" type="String">/,
        "the font family is a saved setting");
    assert.match(config, /<entry name="dashboardFontSize" type="Double">/,
        "and so is the point size");

    const page = read("contents/ui/settings/ConfigDashboard.qml");
    assert.match(page, /property string cfg_dashboardFontFamily/, "the page hands the family to Apply");
    assert.match(page, /property real cfg_dashboardFontSize/, "and the size");
    assert.match(page, /objectName:\s*"fontFamilyCombo"/, "the family picker is findable");
    assert.match(page, /Qt\.fontFamilies\(\)/, "it offers the fonts that are really installed");
    assert.match(page, /objectName:\s*"fontSizeSpin"/, "and the size picker is findable");
    // The preview on that page is the only place the user sees the result before
    // Apply, so it has to be fed the same values.
    assert.match(page, /fontFamily:\s*dashboardSettings\.cfg_dashboardFontFamily/,
        "the live preview is typed with the chosen font");
    assert.match(page, /fontSize:\s*dashboardSettings\.cfg_dashboardFontSize/,
        "at the chosen size");

    const tile = read("contents/ui/components/MetroTile.qml");
    assert.doesNotMatch(tile, /font\.pointSize:\s*[\d.]+/, "no size is baked into a tile binding");
    assert.match(tile, /readonly property real defaultPointSize:\s*DashboardModel\.TILE_POINT_SIZE_DEFAULT/,
        "the size a tile is designed at comes from the model, in one place");
    assert.match(tile, /import "\.\.\/\.\.\/code\/dashboard_model\.mjs" as DashboardModel/,
        "and the module it comes from is imported");

    // A bigger size that did not grow the row would print names as an ellipsis.
    const group = read("contents/ui/components/DashboardGroup.qml");
    assert.match(group, /DashboardModel\.tileRowHeight\(/,
        "the row height is measured from the chosen point size");
    assert.match(group, /tileFontFamily:\s*dashboardRoot|tileFontFamily/, "the group forwards the family");

    const model = read("contents/code/dashboard_model.mjs");
    assert.match(model, /TILE_POINT_SIZE_DEFAULT,/, "and the default size is exported");
    assert.match(model, /tileRowHeight,/, "with the row height it implies");
});
