import QtQuick
import "../../l10n"

// Invisible helper that owns the widget's language: it reads the configured
// language for the Loc singleton and writes a newly chosen one.
//
// `Loc` is a singleton, so it lives in the engine's root context, and a
// component defined in its own file is instantiated in that file's context too
// - while Plasma hands `Plasmoid` to the applet in a separate, per-applet
// context. So neither this file nor any settings page can see `Plasmoid`, and
// reading the configuration here silently yielded nothing: the picker in
// Settings looked like it did nothing at all. The configuration therefore has
// to be handed over by whoever mounts this object and can see it - which the
// applet's main.qml can, and the settings pages cannot.
//
// Every engine (the applet, the settings dialog) has its own Loc, so each of
// them mounts its own bridge.
QtObject {
    id: bridge

    // Handed over by the mount point: `configuration: Plasmoid.configuration`.
    property var configuration: null

    // Where the configuration came from, for the one line logged at startup.
    readonly property string source: bridge.configuration ? "passed in"
        : ((typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? "Plasmoid" : "none")

    // Reads the language the way the configuration actually offers it. The map
    // Plasma hands out is a property map with dynamic keys: a value written by
    // the settings dialog can sit in the file while this engine still answers
    // with what it read at load time, so ask the object itself before falling
    // back to the cached key.
    function readValue() {
        var cfg = bridge.settings()
        if (!cfg)
            return ""

        if (typeof cfg.readConfig === "function") {
            var fromFile = cfg.readConfig("language", "")
            if (fromFile !== undefined && fromFile !== null && String(fromFile).length > 0)
                return String(fromFile)
        }

        if (cfg.language !== undefined && cfg.language !== null && String(cfg.language).length > 0)
            return String(cfg.language)

        return ""
    }

    // Either handed in by the mount point or, where it happens to be visible,
    // found on its own. Kept a function so it is decided again on every read.
    function settings() {
        if (bridge.configuration)
            return bridge.configuration
        if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
            return Plasmoid.configuration
        return null
    }

    // Hands the configured value to the Loc singleton. Called on creation
    // because bindings elsewhere may already have evaluated with the default
    // "system" by the time this object exists, and kept as a public entry
    // point so the applet can re-read the value every time the interface
    // becomes visible again - that is what applies a language chosen in
    // Settings even if the two engines never tell each other anything.
    function refresh() {
        // With nothing to read there is nothing to say: a page of the settings
        // dialog cannot see the configuration, and answering "system" here
        // would undo the language the dialog is already showing.
        if (!bridge.settings())
            return
        var code = bridge.readValue() || "system"
        if (Loc.configuredLanguage === code)
            return
        Loc.configuredLanguage = code
        console.log("HA-hub: language ->", code)
    }

    // The one way to change the language. Writing it into the configuration
    // (instead of only into a cfg_ property waiting for Apply) is what makes
    // the choice survive closing the dialog: the Plasma configuration backend
    // copies cfg_ entries one page at a time, and a page that was re-created or
    // is not the current one hands back its declared "system" default, which
    // KConfig then drops from the file as if it had never been set.
    function setLanguage(code) {
        Loc.configuredLanguage = code
        var cfg = bridge.settings()
        if (!cfg) {
            console.log("HA-hub: language", code, "applies now and is saved on Apply")
            return
        }
        cfg.language = code
        if (typeof cfg.writeConfig === "function")
            cfg.writeConfig()
        console.log("HA-hub: language saved ->", code)
    }

    // What the configuration exposes, in one line. Every accessor above is
    // guarded, and Plasma has shipped this object with different ones over the
    // years, so this is what makes a language report answerable from the
    // journal alone: journalctl --user | grep HA-hub
    readonly property string accessors: {
        var cfg = bridge.settings()
        if (!cfg)
            return "no configuration"
        var have = []
        if (typeof cfg.readConfig === "function") have.push("readConfig")
        if (typeof cfg.writeConfig === "function") have.push("writeConfig")
        if (typeof cfg.valueChanged === "function") have.push("valueChanged")
        if (typeof cfg.keys === "function") have.push("keys")
        have.push(cfg.language !== undefined ? "language" : "no language key")
        return have.join(", ")
    }

    Component.onCompleted: {
        console.log("HA-hub: language bridge started (" + bridge.source + ": " + bridge.accessors + ")")
        var cfg = bridge.settings()
        if (cfg && typeof cfg.valueChanged === "function") {
            cfg.valueChanged.connect(function (key) {
                if (key !== "language")
                    return
                // Every write of the language, from whatever engine shares this
                // map: this is the line that shows who changed it and to what.
                console.log("HA-hub: configuration says language =", String(cfg.language))
                bridge.refresh()
            })
        }
        refresh()
    }
}
