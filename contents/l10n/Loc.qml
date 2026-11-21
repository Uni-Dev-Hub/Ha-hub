pragma Singleton
import QtQuick
import "translations.mjs" as T

// Singleton translation facade. Read Loc.t("Text") inside bindings: they
// depend on Loc.language and re-evaluate instantly when the user switches
// the language in settings (or the system locale changes on next start).
//
// The configured language is pushed in from outside and never read here. A
// QML singleton is instantiated in the engine's root context, while Plasma
// hands `Plasmoid` to the applet in a child context, so `Plasmoid` is always
// undefined inside this file: reading the configuration here silently fell
// back to the system language and the picker in Settings did nothing. The
// components/LanguageBridge.qml object lives in the applet context and keeps
// `configuredLanguage` up to date instead.
QtObject {
    id: loc

    // "system" or a code from translations.LANGUAGES, as saved in
    // Settings -> General. Every engine that paints translated text (the
    // popup, the panel, the settings dialog) has its own Loc instance, so
    // each of them gets the value pushed by its own LanguageBridge.
    property string configuredLanguage: "system"

    readonly property string configured:
        configuredLanguage.length > 0 ? configuredLanguage : "system"

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
    Component.onCompleted: T.setLanguage(language)

    function t(text, a1, a2, a3) {
        var args = [];
        if (a1 !== undefined) args.push(a1);
        if (a2 !== undefined) args.push(a2);
        if (a3 !== undefined) args.push(a3);
        return T.translate(loc.language, text, args);
    }
}
