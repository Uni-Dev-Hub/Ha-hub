import QtQuick
import QtTest
import "../../contents/l10n"

TestCase {
    name: "Localization"

    function test_t_passthrough_and_args() {
        compare(Loc.t("Connected"), "Connected")
        compare(Loc.t("%1 cards", 3), "3 cards")
        compare(Loc.t("Error: %1 of %2", "a", "b"), "Error: a of b")
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
