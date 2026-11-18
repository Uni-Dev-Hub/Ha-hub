pragma Singleton
import QtQuick
import "translations.mjs" as T

// Singleton translation facade. Read Loc.t("Text") inside bindings: they
// depend on Loc.language and re-evaluate instantly when the user switches
// the language in settings (or the system locale changes on next start).
QtObject {
    id: loc

    // "system" or a code from translations.LANGUAGES.
    readonly property string configured:
        (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
            ? (Plasmoid.configuration.language || "system")
            : "system"

    readonly property string systemLanguage: T.normalizeLanguage(
        Qt.locale().uiLanguages.length > 0 ? Qt.locale().uiLanguages[0] : "en")

    readonly property string language:
        configured === "system" ? systemLanguage : T.normalizeLanguage(configured)

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
