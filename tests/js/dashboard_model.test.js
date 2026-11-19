const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");

// Same vm-based loader as ha_helpers.test.js: the module is plain ES modules
// for QML, so tests run it in a bare context with the export block removed.
function loadLibrary(relativePath) {
    let source = fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
    source = source.replace(/^\.pragma library\s*/m, "");
    const context = { console, JSON, Math, Object, Array, parseInt };
    vm.createContext(context);
    source = source.replace(/^import\s+(?:\*\s+as\s+\w+|\{[^}]+\})\s+from\s+"[^"]+";?\s*$/gm, "");
    source = source.replace(/^export\s+(?=(?:async\s+)?(?:function|var|let|const)\b)/gm, "");
    source = source.replace(/^export\s*\{[^}]*\};?\s*$/gm, "");
    vm.runInContext(source, context, { filename: relativePath });
    return context;
}

const model = loadLibrary("contents/code/dashboard_model.mjs");

// The module runs in its own vm realm, so returned objects/arrays have foreign
// prototypes; structural comparisons go through JSON.
const eq = (actual, expected, msg) => assert.equal(JSON.stringify(actual), JSON.stringify(expected), msg);

const sampleGroups = () => [
    {
        id: "g1", name: "Corridor", color: "#0078d7",
        tiles: [
            { entityId: "light.corridor", size: "medium", content: "" },
            { entityId: "sensor.corridor", size: "small", content: "icon" }
        ]
    },
    { id: "g2", name: "Night", color: "#ffd800", tiles: [] }
];
const sampleJson = () => JSON.stringify(sampleGroups());

test("dashboard json parses, tolerates junk and dumps back", () => {
    assert.equal(model.parseGroups(sampleJson()).length, 2);
    eq(model.parseGroups(""), []);
    eq(model.parseGroups("{oops"), []);
    eq(model.parseGroups('{"not": "an array"}'), []);
    assert.equal(JSON.parse(model.dumpGroups(sampleGroups())).length, 2);
});

test("sanitize drops broken entities, fixes sizes and colours", () => {
    const dirty = [
        { id: "a", tiles: [{ entityId: "light.ok", size: "gigantic" }, { size: "small" }, null] },
        { name: 42, color: "not-a-color", tiles: [{ entityId: "light.ok" }] },
        "junk"
    ];
    const clean = model.sanitizeGroups(dirty);
    assert.equal(clean.length, 2);
    assert.equal(clean[0].tiles.length, 1, "entries without entity id are dropped");
    assert.equal(clean[0].tiles[0].size, "medium", "unknown sizes fall back");
    assert.equal(clean[0].color, null);
    assert.equal(clean[0].id !== "", true);
    assert.equal(clean[1].name, "42");
    assert.equal(clean[1].tiles.length, 0, "duplicate entity kept only once");
});

test("entity ids stay unique across all groups", () => {
    const groups = model.sanitizeGroups([
        { id: "a", tiles: [{ entityId: "light.dup" }] },
        { id: "b", tiles: [{ entityId: "light.dup" }, { entityId: "light.other" }] }
    ]);
    eq(model.allTileEntityIds(groups), ["light.dup", "light.other"]);
    assert.equal(model.countTiles(groups), 2);
    assert.equal(model.groupOf(groups, "light.other"), "b");
});

test("legacy cards migrate into one untitled colourless group", () => {
    const cards = JSON.stringify([
        { entityId: "light.a", size: "1x1" },
        { entityId: "switch.b", size: "2x1" },
        { entityId: "climate.c", size: "2x2" },
        { entityId: "bad.size" }
    ]);
    const groups = model.normalizeDashboardModel("", cards);
    assert.equal(groups.length, 1);
    assert.equal(groups[0].name, "");
    assert.equal(groups[0].color, null, "keeps following the system accent");
    eq(groups[0].tiles.map((t) => t.size), ["small", "wide", "large", "medium"]);

    // A configured dashboard wins over the legacy cards...
    assert.equal(model.normalizeDashboardModel(sampleJson(), cards).length, 2);
    // ...and an explicitly emptied one must not resurrect them.
    eq(model.normalizeDashboardModel("[]", cards), []);
    eq(model.normalizeDashboardModel("", "[]"), []);
});

test("hex colour handling is strict and normalised", () => {
    assert.equal(model.isValidHex("#00AaFF"), true);
    assert.equal(model.isValidHex("#00aff"), false);
    assert.equal(model.isValidHex("00aaff"), false);
    assert.equal(model.isValidHex("#00aaff0"), false);
    assert.equal(model.normalizeHex("#00AaFF"), "#00aaff");
    assert.equal(model.normalizeColor("  #112233 "), "#112233");
    assert.equal(model.normalizeColor("red"), null);
});

test("readableTextColor picks a legible text colour", () => {
    assert.equal(model.readableTextColor("#ffd800"), "#1a1a1a", "amber gets dark text");
    assert.equal(model.readableTextColor("#ffffff"), "#1a1a1a");
    assert.equal(model.readableTextColor("#0078d7"), "#ffffff", "blue gets white text");
    assert.equal(model.readableTextColor("#000000"), "#ffffff");
    // Unknown colour must still produce something usable.
    assert.equal(model.readableTextColor("nope"), "#ffffff");
    for (const color of model.METRO_COLORS) {
        assert.match(model.readableTextColor(color), /^#(1a1a1a|ffffff)$/, color);
    }
});

test("tile spans stay inside the grid", () => {
    eq(model.tileSpan("small", 4), { cols: 1, rows: 1 });
    eq(model.tileSpan("medium", 4), { cols: 2, rows: 2 });
    eq(model.tileSpan("wide", 2), { cols: 2, rows: 2 }, "wide never exceeds columns");
    eq(model.tileSpan("large", 2), { cols: 2, rows: 4 });
    eq(model.tileSpan("nonsense", 4), { cols: 4, rows: 4 }, "unknown sizes read as large");
});

test("group CRUD never mutates the stored list", () => {
    const groups = model.sanitizeGroups(sampleGroups());
    const frozen = JSON.stringify(groups);

    const added = model.addGroup(groups, "Garage", "#60a917");
    assert.equal(added.length, 3);
    assert.notEqual(added[2].id, "g1");
    assert.notEqual(added[2].id, "g2", "ids do not collide");
    assert.equal(JSON.stringify(groups), frozen, "input untouched");

    const renamed = model.renameGroup(added, "g3", "Storage");
    assert.equal(renamed[2].name, "Storage");
    const recolored = model.setGroupColor(renamed, "g3", "#FF0000");
    assert.equal(recolored[2].color, "#ff0000");
    const reset = model.setGroupColor(recolored, "g3", "bogus");
    assert.equal(reset[2].color, null, "an invalid colour clears back to the accent");

    const moved = model.moveGroup(reset, "g3", -2);
    assert.equal(moved[0].id, "g3");
    assert.equal(model.moveGroup(moved, "g3", -5)[0].id, "g3", "moving past the edge is a no-op");
    assert.equal(model.moveGroup(moved, "g1", 9)[1].id, "g1", "and the same below");

    const removed = model.removeGroup(moved, "g2");
    assert.equal(removed.length, 2);
    assert.equal(model.removeGroup(moved, "ghost").length, 3);
});

test("tile CRUD keeps entities unique and edits in place", () => {
    const groups = model.sanitizeGroups(sampleGroups());

    const withTile = model.addTile(groups, "g2", "fan.bedroom", "small");
    assert.equal(model.countTiles(withTile), 3);
    assert.equal(model.groupOf(withTile, "fan.bedroom"), "g2");

    // An entity that is already on the dashboard cannot be added twice.
    assert.equal(JSON.stringify(model.addTile(withTile, "g1", "fan.bedroom", "small")),
                 JSON.stringify(withTile));
    assert.equal(JSON.stringify(model.addTile(groups, "ghost", "sensor.new", "")),
                 JSON.stringify(groups), "unknown group is a no-op");

    const resized = model.setTileSize(withTile, "g2", "fan.bedroom", "large");
    assert.equal(resized[1].tiles[0].size, "large");
    assert.equal(model.setTileSize(resized, "g2", "fan.bedroom", "huge")[1].tiles[0].size, "medium");

    const retitled = model.setTileContent(resized, "g2", "fan.bedroom", "title");
    assert.equal(retitled[1].tiles[0].content, "title");
    assert.equal(model.setTileContent(retitled, "g2", "fan.bedroom", "video")[1].tiles[0].content, "");

    const movedBack = model.moveTile(retitled, "fan.bedroom", "g1");
    assert.equal(model.countTiles(movedBack), 3);
    assert.equal(model.groupOf(movedBack, "fan.bedroom"), "g1");
    assert.equal(movedBack[0].tiles[movedBack[0].tiles.length - 1].entityId, "fan.bedroom");
    // Moving into the destination list twice (or to a ghost) changes nothing.
    assert.equal(JSON.stringify(model.moveTile(movedBack, "fan.bedroom", "ghost")),
                 JSON.stringify(movedBack));

    const removed = model.removeTile(movedBack, "g1", "fan.bedroom");
    assert.equal(model.countTiles(removed), 2);
    assert.equal(JSON.stringify(model.removeTile(removed, "g1", "fan.bedroom")), JSON.stringify(removed));
});

test("the whole model survives a save/load round trip", () => {
    let groups = model.sanitizeGroups([]);
    groups = model.addGroup(groups, "Living", "#e81123");
    groups = model.addTile(groups, groups[0].id, "light.living", "wide");
    const json = model.dumpGroups(groups);
    const back = model.normalizeDashboardModel(json, "");
    eq(back, groups);
});
