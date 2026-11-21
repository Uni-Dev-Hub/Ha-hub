import QtQuick
import QtTest
import "../../contents/ui/components" as Components
import "../../contents/l10n"
import "../../contents/l10n/translations.mjs" as T

TestCase {
    name: "LanguageBridge"

    // A configuration of the kind Plasma hands out: an object with dynamic keys
    // that also answers readConfig(), and that remembers a value the settings
    // dialog wrote.
    QtObject {
        id: stored
        property string language: ""
        function readConfig(key, fallback) {
            return key === "language" ? language : fallback
        }
    }

    Components.LanguageBridge {
        id: bridge
        configuration: stored
    }

    // A bridge of a page that cannot see any configuration: it must not answer
    // with the system language and repaint the dialog in it.
    Components.LanguageBridge {
        id: quietBridge
    }

    Text {
        id: liveLabel
        text: Loc.t("Settings")
    }

    function init() {
        Loc.forcedLanguage = ""
        Loc.configuredLanguage = "system"
        stored.language = ""
    }

    // The whole point of the bridge: what the configuration holds is what the
    // widget paints, without a restart and without anyone calling refresh().
    function test_configured_language_reaches_the_widget() {
        stored.language = "kk"
        compare(Loc.configuredLanguage, "kk", "the bridge handed the value over")
        compare(Loc.language, "kk", "resolved to a catalog")
        compare(liveLabel.text, T.translate("kk", "Settings"), "and the widget is in it")

        stored.language = "de"
        compare(liveLabel.text, T.translate("de", "Settings"), "a later change follows at once")
    }

    // A saved language the widget cannot have written itself: a code with a
    // region, or one no catalog covers. Neither may leave the widget languageless.
    function test_a_saved_value_is_read_as_a_language() {
        stored.language = "zh-Hans-CN"
        compare(Loc.language, "zh", "a language tag finds the catalog it belongs to")

        stored.language = "system"
        compare(Loc.language, Loc.systemLanguage, "and 'system' means the system language")

        stored.language = ""
        compare(Loc.language, Loc.systemLanguage, "as does nothing saved at all")
    }

    function test_a_bridge_with_nothing_to_read_stays_quiet() {
        stored.language = "kk"
        compare(quietBridge.speaks, false, "a page's bridge has no source")
        quietBridge.refresh()
        compare(Loc.configuredLanguage, "kk", "and it leaves the language alone")
    }

    // The language of a dialog is the language its page was opened with, which
    // is not necessarily the one already in the file - and the file's own value
    // returns the moment the dialog lets go of it.
    function test_a_page_hands_over_the_language_it_shows() {
        stored.language = "de"
        wait(0)
        compare(Loc.configuredLanguage, "de")

        bridge.pendingLanguage = "ru"
        wait(0) // the value travels through the engine, as it does in the dialog
        compare(Loc.configuredLanguage, "ru", "what the dialog shows wins over what is stored")

        bridge.pendingLanguage = ""
        wait(0)
        compare(Loc.configuredLanguage, "de", "and the stored language returns when the dialog closes")
    }
}
