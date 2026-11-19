import QtQuick
import QtTest
import "../../contents/l10n"
import "../../contents/l10n/translations.mjs" as T

TestCase {
    name: "Localization"

    Item {
        Text { id: liveLabel; text: Loc.t("Settings") }
    }

    function test_language_switch_updates_text_bindings() {
        wait(50)
        var ru = T.translate("ru", "Settings")
        var de = T.translate("de", "Settings")
        verify(ru !== de, "the two translations differ")
        // A Text bound to Loc.t must retranslate instantly - this is the
        // exact mechanism the popup relies on when the language is changed
        // in settings.
        Loc.forcedLanguage = "ru"
        compare(liveLabel.text, ru)
        Loc.forcedLanguage = "de"
        compare(liveLabel.text, de)
        Loc.forcedLanguage = ""
        wait(50)
    }

    function test_catalogs_loaded_in_qml() {
        // The catalogs live in one big module; if Qt failed to parse it the
        // languages would still be listed but every catalog empty.
        compare(T.LANGUAGES.length, 9)
        for (var i = 0; i < T.LANGUAGES.length; i++) {
            var code = T.LANGUAGES[i].code
            if (code === "en") continue
            var catalog = T.CATALOGS[code]
            verify(catalog && Object.keys(catalog).length > 200, code + " catalog loaded")
        }
    }

    function test_catalogs_are_translated() {
        compare(T.translate("ru", "Settings"), "Настройки")
        compare(T.translate("kk", "Settings"), "Баптаулар")
        compare(T.translate("ru", "%1 tiles", [4]), "4 плиток")
        compare(T.translate("de", "Dashboard"), "Dashboard")
        // Language switches are instant: the same call, another language.
        T.setLanguage("ru")
        compare(T.tr("Favorite Devices"), "Избранные устройства")
        T.setLanguage("en")
        compare(T.tr("Favorite Devices"), "Favorite Devices")
        T.setLanguage(Loc.language)
    }

    function test_t_passthrough_and_args() {
        // The active language follows the test host locale, so expectations
        // are expressed through the module rather than hard-coded English.
        compare(Loc.t("Connected"), T.translate(Loc.language, "Connected"))
        compare(Loc.t("zzz %1 zzz %2", "a", "b"), "zzz a zzz b")
        compare(Loc.t("Error: %1 of %2", "a", "b").indexOf("%1"), -1)
        compare(Loc.t("Unknown key %1", null), "Unknown key ")
    }

    function test_language_normalized() {
        // In tests there is no Plasmoid, so "system" wins and the value must
        // always be one of the supported codes.
        var codes = Loc.languages.map(function (l) { return l.code })
        verify(codes.indexOf(Loc.language) !== -1, "language " + Loc.language + " supported")
    }

    function test_system_language_matches_locale() {
        var ui = Qt.locale().uiLanguages
        var expected = (ui.length > 0) ? ui[0].split("-")[0].toLowerCase() : "en"
        var codes = Loc.languages.map(function (l) { return l.code })
        if (codes.indexOf(expected) === -1) expected = "en"
        compare(Loc.language, expected)
    }
}
