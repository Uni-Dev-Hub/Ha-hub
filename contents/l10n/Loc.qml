pragma Singleton
import QtQuick
import "translations.mjs" as T

// Singleton translation facade. Read Loc.t("Text") inside bindings: they
// depend on Loc.language and re-evaluate instantly when the user switches
// the language in settings (or the system locale changes on next start).
QtObject {
    id: loc

    // Re-evaluation trigger: a change of any configuration key bumps this
    // counter, and `configured` reads it. Plasma notifies kcfg property
    // changes too, but the popup and the settings dialog can live in
    // different QML engines, so the explicit configChanged signal is what
    // guarantees the language switches everywhere the moment it is saved.
    // (Connected programmatically below: a QtObject has no default property,
    // so a Connections element would not compile here.)
    property int configRevision: 0

    // "system" or a code from translations.LANGUAGES.
    readonly property string configured: {
        loc.configRevision
        if (typeof Plasmoid === "undefined" || !Plasmoid || !Plasmoid.configuration) {
            return "system"
        }
        return Plasmoid.configuration.language || "system"
    }

    readonly property string systemLanguage: T.normalizeLanguage(
        Qt.locale().uiLanguages.length > 0 ? Qt.locale().uiLanguages[0] : "en")

    // Test-only override; empty in normal operation.
    property string forcedLanguage: ""

    readonly property string language: {
        if (forcedLanguage.length > 0) return T.normalizeLanguage(forcedLanguage)
        return configured === "system" ? systemLanguage : T.normalizeLanguage(configured)
    }

    readonly property var languages: T.LANGUAGES

    // Keep the shared module state in sync so plain JS helpers can translate.
    onLanguageChanged: T.setLanguage(language)
    Component.onCompleted: {
        var cfg = (typeof Plasmoid !== "undefined" && Plasmoid) ? Plasmoid.configuration : null
        if (cfg && cfg.configChanged) {
            cfg.configChanged.connect(function () { loc.configRevision++ })
        }
        T.setLanguage(language)
    }

    function t(text, a1, a2, a3) {
        var args = [];
        if (a1 !== undefined) args.push(a1);
        if (a2 !== undefined) args.push(a2);
        if (a3 !== undefined) args.push(a3);
        return T.translate(loc.language, text, args);
    }
}
