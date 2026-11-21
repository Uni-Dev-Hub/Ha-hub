import QtQuick
import "../../l10n"
import "../../l10n/translations.mjs" as L10N

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

    // What makes the read happen again. The values a running applet is given are
    // a map, and the map reports the keys it changes - that is the notification
    // Apply in the settings dialog produces, and the listener below acts on it.
    // Nothing is reported for a value that moved while nobody was listening: a
    // read that happened once is the value of the moment it happened, forever, so
    // every moment the language could have moved in the meantime bumps this - the
    // popup opening, the dialog handing over a language of its own.
    property int revision: 0

    // What the source answers, before it is turned into a catalog code: a code,
    // "system", or "" when nothing was said.
    readonly property string configured: bridge.readConfigured(bridge.revision)

    // The language of this engine: a catalog code, or "" meaning the system
    // language, which is what Loc resolves from the operating system.
    readonly property string language: L10N.normalizeLanguage(bridge.configured)

    // A bridge only speaks for an engine it can actually read. The settings
    // dialog opens every page of it, and a page that can see neither the
    // configuration nor a language of its own would otherwise answer "the system
    // language" and undo the language the dialog is already showing.
    readonly property bool speaks: bridge.pendingLanguage.length > 0 || bridge.settings() !== null

    // `revision` is only an argument so that the binding above is asked again
    // when it moves; the reading itself depends on nothing else it could watch.
    function readConfigured(revision) {
        if (bridge.pendingLanguage.length > 0)
            return bridge.pendingLanguage
        return bridge.settings() ? bridge.readValue() : ""
    }

    // Asks again what the configuration says. Without this the language an
    // engine paints is the language that was in the file when it started.
    function recheck() {
        bridge.revision = bridge.revision + 1
    }

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
    // blame.
    function refresh() {
        if (!bridge.speaks)
            return
        Loc.configuredLanguage = bridge.configured
        bridge.reportIfNew()
    }

    property string lastLanguage: ""
    property bool reported: false

    // The one notification that exists. What Plasma hands out as a configuration
    // is a property map (`KConfigPropertyMap`, a `QQmlPropertyMap`), and a property
    // map reports the keys it changes. There is no `configChanged`, no
    // `configUpdated`, no `languageChanged` on it - all three were looked for and
    // none is there - so this is how a running widget learns that the language
    // moved, and `recheck()` is what makes the read happen again afterwards.
    //
    // Kept tolerant: the object handed in is not always Plasma's - a settings page
    // hands over nothing, a test hands over a plain object - and those carry no
    // such signal.
    property Connections configListener: Connections {
        target: bridge.configuration
        ignoreUnknownSignals: true
        function onValueChanged(key, value) {
            if (String(key) === "language")
                bridge.recheck()
        }
    }

    // One line per language this bridge actually settled on. Saying it again when
    // it settles on a different one is what makes the live path - Apply in the
    // dialog, a popup that repaints without a restart - visible in the journal at
    // all; without it, "the setting never arrived" and "it arrived and nothing
    // listened" look the same from the outside.
    //
    // The language is worked out here rather than read from `bridge.language`:
    // inside a change notification that property's own binding has not been
    // re-run yet, so a line written from it names the language being left, not
    // the one being entered.
    function reportIfNew() {
        var now = L10N.normalizeLanguage(bridge.configured)
        if (bridge.reported && now === bridge.lastLanguage)
            return
        bridge.reported = true
        bridge.lastLanguage = now
        console.log("HA-hub: language bridge (" + bridge.report() + ")")
    }

    // The pending value can move on its own; so can the configuration, once
    // somebody rechecks it.
    onConfiguredChanged: bridge.refresh()

    // What this bridge can see, in one line, for `journalctl --user -g HA-hub`.
    // Reading the journal is the only way to tell "the configuration holds
    // nothing" from "the configuration was never read", which is the difference
    // between a setting that was not saved and a setting that cannot arrive.
    function report() {
        var catalog = L10N.normalizeLanguage(bridge.configured)
        if (bridge.pendingLanguage.length > 0)
            return "the dialog shows " + bridge.pendingLanguage
                + ", catalog " + (catalog || "system default")
        if (!bridge.settings())
            return "nothing to read in this engine, staying quiet"
        var line = "configuration says " + (bridge.configured.length > 0 ? bridge.configured : "nothing")
            + ", catalog " + (catalog || "system default")
        // The difference between the language being painted and the language in
        // the file: someone has to ask for it, and this says when nobody has.
        var file = bridge.readValue()
        if (file !== bridge.configured)
            line += ", the file says " + (file.length > 0 ? file : "nothing") + ", not re-read yet"
        return line
    }

    Component.onCompleted: {
        bridge.refresh()
        // A bridge that could not speak at all still says what it could see.
        bridge.reportIfNew()
    }
}
