import QtQuick
import "../../l10n"

// Invisible helper that owns the language of one QML engine: it reads what the
// configuration says and hands it to the Loc singleton of that same engine.
//
// `Loc` is a singleton, so it lives in the engine's root context, while Plasma
// hands `Plasmoid` to the applet in a separate, per-applet context - so a file
// of its own, whether a component or a settings page, cannot always see the
// configuration. Reading it where it is not visible silently yielded nothing,
// which is what made the picker in Settings look like it did nothing at all. The
// configuration is therefore handed over by whoever mounts this object and can
// see it (`configuration: Plasmoid.configuration` in the applet), and a page of
// the settings dialog hands over the language it was opened with instead.
//
// Every engine that paints translated text (the popup and the panel, the
// settings dialog) has its own Loc, so each of them mounts its own bridge.
QtObject {
    id: bridge

    // Handed over by the mount point where the configuration is visible.
    property var configuration: null

    // Or handed over by a page of the settings dialog: the language that page
    // was opened with and will write out on Apply. A dialog is painted in the
    // language it is showing, which is not necessarily the one in the file yet.
    property string pendingLanguage: ""

    // What the source answers, before it is turned into a catalog code: a code,
    // "system", or "" when nothing was said. A function of the reading below, so
    // it is asked again whenever the configuration changes.
    readonly property string configured: bridge.pendingLanguage.length > 0
        ? bridge.pendingLanguage
        : (bridge.settings() ? bridge.readValue() : "")

    // The language of this engine: a catalog code, or "" meaning the system
    // language, which is what Loc resolves from the operating system.
    readonly property string language: L10N.normalizeLanguage(bridge.configured)

    // A bridge only speaks for an engine it can actually read. The settings
    // dialog opens every page of it, and a page that can see neither the
    // configuration nor a language of its own would otherwise answer "the system
    // language" and undo the language the dialog is already showing.
    readonly property bool speaks: bridge.pendingLanguage.length > 0 || bridge.settings() !== null

    // Either handed in by the mount point or, where it happens to be visible,
    // found on its own. Kept a function so it is decided again on every read.
    function settings() {
        if (bridge.configuration)
            return bridge.configuration
        try {
            if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
                return Plasmoid.configuration
        } catch (e) {
        }
        return null
    }

    // Reads the language the way the configuration actually offers it. The map
    // Plasma hands out is a property map with dynamic keys: a value written by
    // the settings dialog can sit in the file while the applet's engine still
    // answers with what it read at load time, so ask the object itself before
    // falling back to the cached key.
    function readValue() {
        var cfg = bridge.settings()
        if (!cfg)
            return ""
        try {
            if (typeof cfg.readConfig === "function") {
                var fromFile = cfg.readConfig("language", "")
                if (fromFile)
                    return String(fromFile)
            }
        } catch (e) {
        }
        try {
            if (cfg.language)
                return String(cfg.language)
        } catch (e) {
        }
        return ""
    }

    // Hands the language to the Loc singleton. Everything painted through
    // Loc.t() follows the binding on its own; the call is kept because text put
    // together in JavaScript - a model, a summary line - has no binding to
    // blame, and asking the applet to refresh when its popup opens is what makes
    // a language chosen in Settings reach a running widget.
    function refresh() {
        if (!bridge.speaks)
            return
        Loc.configuredLanguage = bridge.configured
    }

    // Either source can move on its own: the configuration from the other
    // engine, the pending value from a pick in the dialog.
    onConfiguredChanged: bridge.refresh()
    onPendingLanguageChanged: bridge.refresh()

    // What this bridge can see, in one line, for `journalctl --user -g HA-hub`.
    // Reading the journal is the only way to tell "the configuration holds
    // nothing" from "the configuration was never read", which is the difference
    // between a setting that was not saved and a setting that cannot arrive.
    function report() {
        if (bridge.pendingLanguage.length > 0)
            return "the dialog shows " + bridge.pendingLanguage
                + ", catalog " + (bridge.language || "system default")
        if (!bridge.settings())
            return "nothing to read in this engine, staying quiet"
        var raw = bridge.readValue()
        return "configuration says " + (raw.length > 0 ? raw : "nothing")
            + ", catalog " + (bridge.language || "system default")
    }

    Component.onCompleted: {
        bridge.refresh()
        console.log("HA-hub: language bridge (" + bridge.report() + ")")
    }
}
