const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.join(__dirname, "..", "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");

const PAGES = [
    "contents/ui/settings/ConfigGeneral.qml",
    "contents/ui/settings/ConfigDashboard.qml",
    "contents/ui/settings/ConfigAppearance.qml",
    "contents/ui/settings/ConfigFavorites.qml",
];

// `Loc` is a QML singleton, so it lives in the engine's root context, while
// Plasma exposes `Plasmoid` only in the per-applet child context: reading the
// configuration from inside the singleton always yielded nothing, and the
// interface stayed on the system language. The language therefore arrives from
// outside - from the one bridge of the engine that can see it.
test("the Loc singleton never reads the configuration itself", () => {
    const loc = read("contents/l10n/Loc.qml");
    assert.match(loc, /pragma Singleton/, "Loc is a singleton");
    assert.doesNotMatch(loc, /Plasmoid\./, "the singleton cannot see Plasmoid");
    assert.match(loc, /property string configuredLanguage/, "the language is pushed in");
});

test("the language bridge resolves the configured language for its engine", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.match(bridge, /readonly property string configured/, "what the source says, read again on demand");
    assert.match(bridge, /readonly property string language/, "normalised to a catalog code");
    assert.match(bridge, /Loc\.configuredLanguage = bridge\.configured/, "...and that is what the singleton is fed");
    assert.match(bridge, /onConfiguredChanged/, "a new value arrives without anyone asking");
    assert.match(bridge, /Component\.onCompleted/, "the first value is handed over on creation");
});

// The configuration object Plasma hands out is a property map with dynamic
// keys. A settings dialog that writes through its own copy can leave the
// applet's map answering with what it read at load time, so the read asks the
// object itself before trusting the cached key.
test("the bridge re-reads the file instead of trusting a cached key", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.match(bridge, /function readValue/, "the read is a function, so it runs again on demand");
    assert.match(bridge, /cfg\.readConfig\("language"/, "it asks the configuration object first");
    assert.match(bridge, /function refresh/, "and the applet can call it whenever the interface opens");
    // "The language does not apply" is either a value that was never stored or a
    // value that never arrived, and only the journal tells those apart.
    assert.match(bridge, /function report/, "and it says in one line what it could see");
    assert.match(bridge, /console\.log\(/, "in the journal, at startup");
});

// The settings dialog keeps a copy of the configuration. A pick that wrote the
// language straight into the applet's configuration - around that copy - was
// undone a few seconds later, when the dialog closed and its copy, still holding
// the old language, was written back. One writer, the Plasma way: cfg_ and Apply.
test("nobody writes the configuration behind the dialog's copy", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.doesNotMatch(bridge, /cfg\.language\s*=/, "the bridge never writes the configuration...");
    assert.doesNotMatch(bridge, /writeConfig\s*\(/, "...let alone pushes it to disk");

    const general = read("contents/ui/settings/ConfigGeneral.qml");
    assert.match(general, /function selectLanguage\(code\)/, "one entry point for a pick");
    assert.match(general, /function selectLanguage\(code\)\s*\{[^}]*cfg_language\s*=\s*code/s,
        "the pick lands in cfg_language, which Apply copies");
});

// A page cannot see the applet's configuration, so a bridge mounted by a page
// would answer "the system language" and repaint the whole dialog in it. Only a
// bridge that can actually read something is allowed to say anything.
test("a bridge with nothing to read stays quiet", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.match(bridge, /readonly property bool speaks/, "whether this bridge has a source at all");
    assert.match(bridge, /function refresh\(\)\s*\{\s*\r?\n\s*if \(!bridge\.speaks\)/,
        "and it says nothing without one");
});

// A translated string inside the ComboBox model rebuilds the model exactly when
// the language changes, and the control resets currentIndex when that happens.
test("the language picker keeps a stable model", () => {
    const general = read("contents/ui/settings/ConfigGeneral.qml");
    const combo = general.match(/Controls\.ComboBox \{[\s\S]*?\n        \}/);
    assert.ok(combo, "the language combo is there");
    assert.doesNotMatch(combo[0], /model:\s*[\w.]*[Ii]tems/, "no translated model rebuilt on the fly");
    assert.match(combo[0], /Loc\.t\("System language"\)/, "the label is translated on its own");
    assert.match(combo[0], /displayText:/, "and only where it is displayed");
});

// The language is one setting with one meaning: what the configuration holds.
// The applet reads its own configuration; the page of a settings dialog reads
// the copy the dialog was opened with, which is the language that dialog shows.
test("every engine is told where to read the language", () => {
    const main = read("contents/ui/main.qml");
    const applet = main.match(/Components\.LanguageBridge\s*\{[\s\S]*?\n {4}\}/);
    assert.ok(applet, "the applet mounts the bridge");
    assert.match(applet[0], /configuration:\s*Plasmoid\.configuration/, "with the applet's configuration");
    assert.match(main, /appletLanguageBridge\.refresh\(\)/, "and re-reads it when the popup is opened");

    const general = read("contents/ui/settings/ConfigGeneral.qml");
    const page = general.match(/Components\.LanguageBridge\s*\{[\s\S]*?\n {8}\}/);
    assert.ok(page, "the general page mounts the bridge");
    assert.match(page[0], /pendingLanguage:\s*\w+\.cfg_language/, "with the language the dialog was opened with");
    assert.doesNotMatch(general, /Loc\.configuredLanguage\s*=\s*cfg_language/,
        "and the page does not push that language past the bridge");

    // The list in the picker is the list of catalogs: a language that ships
    // cannot be missing from Settings, which is how "the translations exist but
    // cannot be chosen" happened in the first place.
    assert.match(general, /concat\(Loc\.languages\)/, "the picker starts from the module's own list");
    const loc = read("contents/l10n/Loc.qml");
    assert.match(loc, /readonly property var languages:\s*T\.LANGUAGES/,
        "which is the catalog list itself, not a copy of its own");
});

// Every engine that paints translated text mounts the bridge.
test("every engine that paints translated text mounts the bridge", () => {
    const files = [
        "contents/ui/main.qml",
        ...PAGES,
        // The list of sections in the dialog is translated too, and it is built
        // by the dialog's engine before any page of it has been shown.
        "contents/config/config.qml",
    ];
    for (const file of files) {
        assert.match(read(file), /Components\.LanguageBridge\s*\{/, file + " must mount LanguageBridge");
    }
});
