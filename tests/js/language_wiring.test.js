const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.join(__dirname, "..", "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");

// Regression guard for "the language picker does nothing". `Loc` is a QML
// singleton, so it lives in the engine's root context, while Plasma exposes
// `Plasmoid` only in the per-applet child context: reading the configuration
// from inside the singleton always yielded undefined and the interface stayed
// on the system language.
test("the Loc singleton never reads the configuration itself", () => {
    const loc = read("contents/l10n/Loc.qml");
    assert.match(loc, /pragma Singleton/, "Loc is a singleton");
    assert.doesNotMatch(loc, /Plasmoid\.configuration/, "the singleton cannot see Plasmoid");
    assert.match(loc, /property string configuredLanguage/, "the language is pushed in");
});

test("the language bridge moves the configured value into Loc", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.match(bridge, /Plasmoid\.configuration/, "the bridge reads the configuration...");
    assert.match(bridge, /Loc\.configuredLanguage\s*=/, "...and pushes it into the singleton");
    assert.match(bridge, /Component\.onCompleted/, "the first value is handed over on creation");
});

// The configuration object Plasma hands out is a property map with dynamic
// keys. A settings dialog that writes through its own instance can leave the
// applet's map answering with what it read at load time, so the read asks the
// object itself before trusting the cached key.
test("the bridge re-reads the file instead of trusting a cached key", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.match(bridge, /function readValue/, "the read is a function, so it runs again on demand");
    assert.match(bridge, /cfg\.readConfig\("language"/, "it asks the configuration object first");
    assert.match(bridge, /function refresh/, "and the applet can call it whenever the interface opens");
    assert.match(bridge, /console\.log\(/, "and says in the journal what it settled on");
});

// The settings dialog keeps a copy of the configuration. A pick that wrote the
// language straight into the applet's configuration - around that copy - was
// undone a few seconds later, when the dialog closed and its copy, still holding
// the old language, was written back. One writer, the Plasma way: cfg_ and Apply.
test("a page hands the language over the way Apply copies it, and never past it", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.doesNotMatch(bridge, /cfg\.language\s*=/, "the bridge never writes the configuration...");
    assert.doesNotMatch(bridge, /writeConfig\s*\(/, "...let alone pushes it to disk");
    assert.match(bridge, /valueChanged/, "...it watches what arrives instead");

    const general = read("contents/ui/settings/ConfigGeneral.qml");
    assert.match(general, /function selectLanguage\(code\)/, "one entry point for a pick");
    assert.match(general, /function selectLanguage\(code\)\s*\{[^}]*cfg_language\s*=\s*code/s,
        "the pick lands in cfg_language, which Apply copies");
    assert.doesNotMatch(general, /Bridge\.setLanguage\(/, "and nowhere else");
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

// Every component is created in the context of the file that defines it, while
// Plasma keeps `Plasmoid` in a context of its own for the applet. A component
// in its own file therefore cannot see the configuration no matter where it is
// mounted - which is why the applet hands it over explicitly. Without that line
// the widget never learned what language it was configured for.
test("the applet hands its configuration to the bridge", () => {
    const main = read("contents/ui/main.qml");
    const mount = main.match(/Components\.LanguageBridge\s*\{[\s\S]*?\n {4}\}/);
    assert.ok(mount, "the applet mounts the bridge");
    assert.match(mount[0], /configuration:\s*Plasmoid\.configuration/, "and passes the configuration in");
    assert.match(main, /appletLanguageBridge\.refresh\(\)/, "and re-reads it when the popup is opened");
});

// A settings page is a file of its own too, so the same limit applies there.
// The page still owns the language the dialog was opened with (cfg_language),
// and that is what the translated dialog is built from.
test("the general page seeds the dialog's language", () => {
    const general = read("contents/ui/settings/ConfigGeneral.qml");
    assert.match(general, /onCfg_languageChanged:\s*\{[^}]*Loc\.configuredLanguage\s*=\s*cfg_language/s,
        "the language arriving with the page is pushed into Loc");
    // The declared value is what Apply writes when nothing was handed over, so
    // a hard-coded "system" here erased a chosen language a few seconds later:
    // KConfig drops an entry that equals its default, and the widget went back
    // to the system language on its own.
    assert.match(general, /property string cfg_language:\s*Loc\.configuredLanguage/,
        "the page holds the language it is showing, not a hard-coded default");
    assert.doesNotMatch(general, /property string cfg_language:\s*"/,
        "and never a literal language of its own");
});

// Every engine that paints translated text mounts the bridge.
test("every engine that paints translated text mounts the bridge", () => {
    const files = [
        "contents/ui/main.qml",
        "contents/ui/settings/ConfigGeneral.qml",
        "contents/ui/settings/ConfigDashboard.qml",
        "contents/ui/settings/ConfigAppearance.qml",
        "contents/ui/settings/ConfigFavorites.qml",
        // The list of sections in the dialog is translated too, and it is built
        // by the dialog's engine before any page of it has been shown.
        "contents/config/config.qml",
    ];
    for (const file of files) {
        assert.match(read(file), /Components\.LanguageBridge\s*\{/, file + " must mount LanguageBridge");
    }
});
