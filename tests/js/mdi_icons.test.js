const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");

// Same vm-based loader as the other suites: the module is plain ES modules for
// QML, so tests run it in a bare context with the export block removed.
function loadLibrary(relativePath) {
    let source = fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
    source = source.replace(/^\.pragma library\s*/m, "");
    const context = { console, JSON, Math, Object, Array, String, parseInt };
    vm.createContext(context);
    source = source.replace(/^import\s+(?:\*\s+as\s+\w+|\{[^}]+\})\s+from\s+"[^"]+";?\s*$/gm, "");
    source = source.replace(/^export\s+(?=(?:async\s+)?(?:function|var|let|const)\b)/gm, "");
    source = source.replace(/^export\s*\{[^}]*\};?\s*$/gm, "");
    vm.runInContext(source, context, { filename: relativePath });
    return context;
}

const mdi = loadLibrary("contents/code/mdi_icons.mjs");

test("the generated MDI table matches the bundled font", () => {
    const names = Object.keys(mdi.MDI_CODEPOINTS);
    assert.ok(names.length > 7000, `the table should cover the whole font, found ${names.length}`);
    // MDI sits in the private use areas: the old icons in the BMP one, the
    // newer ones in the top plane. Anything else would mean the generated
    // codepoints stopped matching the TTF in contents/fonts/.
    const inPrivateUse = (codepoint) =>
        (codepoint >= 0xe000 && codepoint <= 0xf8ff) || (codepoint >= 0xf0000 && codepoint <= 0xfffff);
    for (const codepoint of names.map((name) => mdi.MDI_CODEPOINTS[name])) {
        assert.ok(inPrivateUse(codepoint), `codepoint ${codepoint} is out of the private use areas`);
    }
});

test("mdi lookups answer by name", () => {
    // The icons Home Assistant picks for the domains the dashboard shows.
    for (const name of ["lightbulb", "ceiling-light", "floor-lamp", "thermometer",
                        "motion-sensor", "lock", "window-shutter", "play", "blinds"]) {
        assert.ok(mdi.mdiCodepoint(name) > 0, `${name} must be drawable`);
    }
    assert.equal(mdi.mdiCodepoint("  Lightbulb  "), mdi.mdiCodepoint("lightbulb"),
        "names are trimmed and case-insensitive like the HA frontend");
    assert.equal(mdi.mdiCodepoint("definitely-not-an-icon"), 0);
    assert.equal(mdi.mdiCodepoint(""), 0);
    assert.equal(mdi.mdiCodepoint(null), 0);
});

test("mdiGlyph hands over the character to draw", () => {
    assert.equal(mdi.mdiGlyph("lightbulb"), String.fromCodePoint(mdi.mdiCodepoint("lightbulb")));
    assert.equal(mdi.mdiGlyph("definitely-not-an-icon"), "");
});
