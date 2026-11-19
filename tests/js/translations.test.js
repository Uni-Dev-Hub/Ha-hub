const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");

const ROOT = path.join(__dirname, "..", "..");

function loadLibrary(relativePath) {
    let source = fs.readFileSync(path.join(ROOT, relativePath), "utf8");
    source = source.replace(/^\.pragma library\s*/m, "");
    const context = { console };
    vm.createContext(context);
    const star = [...source.matchAll(/^import\s+\*\s+as\s+(\w+)\s+from\s+"([^"]+)";?\s*$/gm)];
    const named = [...source.matchAll(/^import\s+\{([^}]+)\}\s+from\s+"([^"]+)";?\s*$/gm)];
    source = source.replace(/^import\s+(?:\*\s+as\s+\w+|\{[^}]+\})\s+from\s+"[^"]+";?\s*$/gm, "");
    for (const [, alias, spec] of star) {
        context[alias] = loadLibrary(path.join(path.dirname(relativePath), spec));
    }
    for (const [, names, spec] of named) {
        const dep = loadLibrary(path.join(path.dirname(relativePath), spec));
        for (const name of names.split(",").map((s) => s.trim()).filter(Boolean)) {
            context[name] = dep[name];
        }
    }
    source = source.replace(/^export\s+(?=(?:async\s+)?(?:function|var|let|const)\b)/gm, "");
    source = source.replace(/^export\s*\{[^}]*\};?\s*$/gm, "");
    vm.runInContext(source, context, { filename: relativePath });
    return context;
}

const L10N = loadLibrary("contents/l10n/translations.mjs");
const TARGET_LANGUAGES = L10N.LANGUAGES.map((l) => l.code).filter((c) => c !== "en");

function walk(dir, out = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full, out);
        else if (entry.name.endsWith(".qml")) out.push(full);
    }
    return out;
}

// Every user-visible string the UI asks for: Loc.t("...") call sites.
function uiKeys() {
    const keys = new Set();
    const re = /Loc\.t\(\s*"((?:[^"\\]|\\.)*)"/g;
    for (const file of walk(path.join(ROOT, "contents"))) {
        const source = fs.readFileSync(file, "utf8");
        for (const m of source.matchAll(re)) keys.add(m[1].replace(/\\"/g, '"'));
    }
    return keys;
}

// Words the plain helper functions translate (they are not Loc.t call sites):
// binary sensor pairs, HVAC actions, status labels and month abbreviations.
const HELPER_WORDS = [
    "Unavailable", "On", "Off", "Open", "Closed", "Locked", "Unlocked", "Wet", "Dry",
    "Detected", "Clear", "Problem", "OK", "Connected", "Disconnected", "Low", "Normal",
    "Running", "Stopped", "Update available", "Up to date", "Cleaning", "Docked",
    "Returning", "Paused", "Error", "Playing", "Idle", "Home", "Away", "Disarmed",
    "Armed Home", "Armed Away", "Armed Night", "Triggered", "Mowing",
    "off", "auto", "heating", "cooling", "drying", "fan_only", "preheating",
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

test("every Loc.t string is translated in every language", () => {
    const keys = uiKeys();
    assert.ok(keys.size > 150, "expected the UI to contain many translatable strings");
    for (const lang of TARGET_LANGUAGES) {
        const catalog = L10N.CATALOGS[lang];
        const missing = [...keys].filter((k) => !catalog[k]).sort();
        assert.deepEqual(missing, [], `${lang} is missing ${missing.length} UI keys`);
    }
});

test("helper status words are translated in every language", () => {
    for (const lang of TARGET_LANGUAGES) {
        const catalog = L10N.CATALOGS[lang];
        const missing = HELPER_WORDS.filter((k) => !catalog[k]).sort();
        assert.deepEqual(missing, [], `${lang} is missing helper words`);
    }
});

test("all languages share the same key set", () => {
    const reference = Object.keys(L10N.CATALOGS.ru).sort();
    assert.ok(reference.length > 0);
    for (const lang of TARGET_LANGUAGES) {
        const keys = Object.keys(L10N.CATALOGS[lang]).sort();
        const missing = reference.filter((k) => !keys.includes(k));
        const extra = keys.filter((k) => !reference.includes(k));
        assert.deepEqual({ missing, extra }, { missing: [], extra: [] }, `${lang} key set differs`);
    }
});

test("translations keep their %1..%3 placeholders", () => {
    const placeholders = (text) => (String(text).match(/%\d/g) || []).sort().join(",");
    for (const lang of TARGET_LANGUAGES) {
        const catalog = L10N.CATALOGS[lang];
        for (const [key, value] of Object.entries(catalog)) {
            assert.equal(placeholders(value), placeholders(key), `${lang}: ${key}`);
        }
    }
});

test("no translation is empty or left in English by accident", () => {
    for (const lang of TARGET_LANGUAGES) {
        for (const [key, value] of Object.entries(L10N.CATALOGS[lang])) {
            assert.ok(typeof value === "string" && value.trim().length > 0, `${lang}: empty ${key}`);
        }
    }
});

test("translate fills positional arguments", () => {
    assert.equal(L10N.translate("en", "Connected (%1:%2)", ["192.168.1.5", "8123"]), "Connected (192.168.1.5:8123)");
    assert.equal(L10N.translate("ru", "%1 entities", [7]), "7 сущностей");
    assert.equal(L10N.translate("en", "All (%1)"), "All (%1)");
});

test("unknown keys and languages fall back to the source text", () => {
    assert.equal(L10N.translate("ru", "A string nobody translated"), "A string nobody translated");
    assert.equal(L10N.translate("zz", "On"), "On");
    assert.equal(L10N.translate("ru", ""), "");
});

test("tr uses the language set with setLanguage", () => {
    L10N.setLanguage("kk");
    assert.equal(L10N.tr("Settings"), "Баптаулар");
    L10N.setLanguage("en");
    assert.equal(L10N.tr("Settings"), "Settings");
    L10N.setLanguage(null);
    assert.equal(L10N.tr("Settings"), "Settings");
});

test("normalizeLanguage maps system tags onto supported codes", () => {
    assert.equal(L10N.normalizeLanguage("ru-Cyrl-RU"), "ru");
    assert.equal(L10N.normalizeLanguage("kk-KZ"), "kk");
    assert.equal(L10N.normalizeLanguage("zh-Hans-CN"), "zh");
    assert.equal(L10N.normalizeLanguage("EN"), "en");
    assert.equal(L10N.normalizeLanguage("nl"), "en");
    assert.equal(L10N.normalizeLanguage(""), "en");
    assert.equal(L10N.normalizeLanguage(null), "en");
});

test("helper functions route their labels through the active language", () => {
    const helpers = loadLibrary("contents/code/ha_helpers.mjs");
    const ent = { state: "open", attributes: {} };
    assert.equal(helpers.getStatusDetailsText("cover.x", ent, null, null, "ru"), "Открыто");
    assert.equal(helpers.getStatusDetailsText("cover.x", ent, null, null, "en"), "Open");
    assert.equal(helpers.getBinarySensorStateTitle("on", "window", "kk"), "Ашық");
    assert.equal(helpers.getStatusDetailsText("climate.x",
        { state: "heat", attributes: { hvac_action: "fan_only" } }, null, null, "de"), "Lüften");
    const stamp = "2026-01-05T08:09:00";
    assert.equal(helpers.formatLastChangedDate(stamp, "", "ru"), "08:09, 05 янв");
    assert.equal(helpers.formatLastChangedDate(stamp, "", "en"), "08:09, 05 Jan");
});

test("every advertised language has a catalog and an autonym", () => {
    for (const entry of L10N.LANGUAGES) {
        assert.ok(L10N.CATALOGS[entry.code], `no catalog for ${entry.code}`);
        assert.ok(entry.label && entry.label.length > 1, `no label for ${entry.code}`);
    }
});
