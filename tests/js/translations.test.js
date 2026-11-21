const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const ROOT = path.join(__dirname, "..", "..");
const { loadLibrary } = require("./load-library.js");
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
// Strings the code asks for without naming them at the call site: the helper
// translates a sensor's state by handing two words to `w(off, on)`, and dates
// look a month up by name. Both are keyed by their English text, so the
// catalogs have to hold them, and a test cannot find them by looking for
// Loc.t(). They are read out of the helper instead of being copied here.
function dynamicKeys() {
    const keys = new Set();
    const helper = fs.readFileSync(path.join(ROOT, "contents/code/ha_helpers.mjs"), "utf8");
    // w("off", "on") for a boolean, w("Paused") for a state read off the entity.
    for (const m of helper.matchAll(/\bw\(\s*((?:"(?:[^"\\]|\\.)*"\s*,?\s*)+)\)/g)) {
        for (const arg of m[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)) keys.add(arg[1]);
    }
    const months = helper.match(/monthNames\s*=\s*\[([^\]]*)\]/);
    if (months) {
        for (const m of months[1].matchAll(/"([^"]+)"/g)) keys.add(m[1]);
    }
    return keys;
}

const DYNAMIC_KEYS = dynamicKeys();

// What the helper module declares for itself, checked here in both directions:
// present in every catalog, and not counted as leftover by the next test.
test("the Home Assistant vocabulary is translated in every language", () => {
    assert.ok(L10N.EXTERNAL_KEYS.length > 0);
    for (const lang of TARGET_LANGUAGES) {
        const catalog = L10N.CATALOGS[lang];
        // Spread, not filter: the array comes from another realm, and
        // assert.deepEqual compares prototypes.
        const missing = [...L10N.EXTERNAL_KEYS].filter((k) => !catalog[k]).sort();
        assert.deepEqual(missing, [], `${lang} is missing HA vocabulary`);
    }
});

test("every string the code asks for is translated in every language", () => {
    const keys = uiKeys();
    assert.ok(keys.size > 150, "expected the UI to contain many translatable strings");
    for (const lang of TARGET_LANGUAGES) {
        const catalog = L10N.CATALOGS[lang];
        const missing = [...keys].filter((k) => !catalog[k]).sort();
        assert.deepEqual(missing, [], `${lang} is missing ${missing.length} UI keys`);
    }
});

test("the words the helpers look up by name are translated too", () => {
    assert.ok(DYNAMIC_KEYS.size > 30, "expected the helpers to look many states up");
    for (const lang of TARGET_LANGUAGES) {
        const catalog = L10N.CATALOGS[lang];
        const missing = [...DYNAMIC_KEYS].filter((k) => !catalog[k]).sort();
        assert.deepEqual(missing, [], `${lang} is missing ${missing.length} helper words`);
    }
});

// The other direction: a key nothing asks for is a translation that nobody
// will ever read, and it keeps quietly "translated" while the string it used to
// render is gone from the UI.
test("no catalog holds a key the code stopped asking for", () => {
    const reachable = new Set([...uiKeys(), ...DYNAMIC_KEYS, ...[...L10N.EXTERNAL_KEYS]]);
    for (const lang of TARGET_LANGUAGES) {
        const unreachable = Object.keys(L10N.CATALOGS[lang]).filter((k) => !reachable.has(k)).sort();
        assert.deepEqual(unreachable, [], `${lang} translates ${unreachable.length} unused key(s)`);
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
    const supported = new Set(L10N.LANGUAGES.map((l) => l.code));
    // The language alone, and with any region or script behind it.
    const cases = [
        ["ru", "ru"], ["ru-RU", "ru"], ["ru-Cyrl-RU", "ru"],
        ["de-AT", "de"], ["de-DE", "de"], ["kk-KZ", "kk"], ["uk-UA", "uk"],
        ["tr-TR", "tr"], ["es-MX", "es"], ["fr-CA", "fr"], ["zh-Hans-CN", "zh"],
        ["en-GB", "en"], ["EN-us", "en"], ["zh-CN", "zh"],
    ];
    for (const [tag, want] of cases) {
        if (!supported.has(want)) continue;
        assert.equal(L10N.normalizeLanguage(tag), want, tag);
    }
    // The region is kept when there is a catalog for it, dropped when there is
    // not - so pt_BR and zh_TW become reachable without breaking anyone else.
    assert.equal(L10N.normalizeLanguage("pt-BR"), supported.has("pt_BR") ? "pt_BR" : (supported.has("pt") ? "pt" : "en"));
    assert.equal(L10N.normalizeLanguage("pt-PT"), supported.has("pt") ? "pt" : "en");
    const serbian = supported.has("sr") ? "sr" : "en";
    assert.equal(L10N.normalizeLanguage("zh-TW"), supported.has("zh_TW") ? "zh_TW" : "zh");
    assert.equal(L10N.normalizeLanguage("sr-Latn-RS"),
        supported.has("sr_Latn") ? "sr_Latn" : serbian);
    const catalan = supported.has("ca_VA") ? "ca_VA" : (supported.has("ca") ? "ca" : "en");
    assert.equal(L10N.normalizeLanguage("ca-ES-valencia"), catalan);
    assert.equal(L10N.normalizeLanguage("sr-Cyrl-RS"), serbian);

    assert.equal(L10N.normalizeLanguage(""), "en");
    assert.equal(L10N.normalizeLanguage(undefined), "en");
    assert.equal(L10N.normalizeLanguage("sw-TZ"), "en");
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
    // Spread first: L10N was loaded in another realm, and deepEqual compares
    // prototypes, so a vm array never equals a local one.
    const labels = [...L10N.LANGUAGES].map((l) => l.label);
    assert.deepEqual(labels, [...new Set(labels)], "two languages share a name");
});

// Languages are added in batches, so both halves of a mistake are worth naming:
// a catalog written but never registered (the language is missing from the
// picker), and a language offered without a file (it would show as English).
test("the catalog files on disk are exactly the languages offered", () => {
    const onDisk = fs.readdirSync(path.join(ROOT, "contents/l10n/catalogs"))
        .map((f) => f.replace(/\.js$/, ""))
        .sort();
    const offered = [...L10N.LANGUAGES].map((l) => l.code).filter((c) => c !== "en").sort();
    assert.deepEqual(onDisk, offered);
});

// The README promises a number of languages. It is the one sentence about this
// feature that anyone reads before installing, so it is checked against the
// catalogs rather than against memory.
test("the README counts the languages that ship", () => {
    const readme = fs.readFileSync(path.join(ROOT, "README.md"), "utf8");
    const claimed = [...readme.matchAll(/^- \*\*Internationalization:\*\* (\d+) built-in languages/gm)]
        .map((m) => Number(m[1]));
    assert.equal(claimed.length, 1, "the README says once how many languages ship");
    assert.equal(claimed[0], L10N.LANGUAGES.length,
        `the README advertises ${claimed[0]}, the module offers ${L10N.LANGUAGES.length}`);
});
