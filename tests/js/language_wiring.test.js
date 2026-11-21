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

// The old path kept the language in a cfg_ property and let Plasma's Apply
// copy it over - a page that was re-created or not current handed back its
// declared "system" default, and the saved language was wiped from the file.
test("the language is written to the configuration, not left for Apply", () => {
    const bridge = read("contents/ui/components/LanguageBridge.qml");
    assert.match(bridge, /function setLanguage/, "the bridge can set the language...");
    assert.match(bridge, /cfg\.language\s*=\s*code/, "...into the configuration itself");
    assert.match(bridge, /writeConfig/, "...and straight to disk");

    const general = read("contents/ui/settings/ConfigGeneral.qml");
    assert.match(general, /function selectLanguage\(code\)/, "one entry point for a pick");
    assert.match(general, /settingsLanguageBridge\.setLanguage\(code\)/, "the page routes through the bridge");
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
    assert.match(general, /property string cfg_language/, "and the page holds it");
});

// Every engine that paints translated text mounts the bridge.
test("every engine that paints translated text mounts the bridge", () => {
    const files = [
        "contents/ui/main.qml",
        "contents/ui/settings/ConfigGeneral.qml",
        "contents/ui/settings/ConfigDashboard.qml",
        "contents/ui/settings/ConfigAppearance.qml",
        "contents/ui/settings/ConfigFavorites.qml",
    ];
    for (const file of files) {
        assert.match(read(file), /Components\.LanguageBridge\s*\{/, file + " must mount LanguageBridge");
    }
});
