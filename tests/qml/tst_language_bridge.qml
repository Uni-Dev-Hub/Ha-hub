import QtQuick
import QtTest
import "../../contents/ui/components" as Components
import "../../contents/l10n"
import "../../contents/l10n/translations.mjs" as T

TestCase {
    name: "LanguageBridge"

    // A configuration of the kind Plasma hands out: a property map with dynamic
    // keys that also answers readConfig(), that remembers a value the settings
    // dialog wrote, and that reports the keys it changes - `valueChanged` is the
    // only notification there is: `configChanged`, `configUpdated` and a per-entry
    // `languageChanged` were all looked for on Plasma's own object, and none
    // exists.
    QtObject {
        id: stored
        signal valueChanged(string key, var value)
        property string language: ""
        function readConfig(key, fallback) {
            return key === "language" ? language : fallback
        }
        onLanguageChanged: stored.valueChanged("language", language)
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
        bridge.pendingLanguage = ""
        bridge.recheck()
    }

    // The whole point of the bridge: what the configuration holds is what the
    // widget paints - after the widget asks, which is what opening the popup
    // does. The configuration is a map of values with no change signal of its
    // own, so a read that happened once is the value of that moment forever.
    // The language arrives after the widget asks, which is what opening the
    // popup does. A configuration that announced its changes would need no
    // asking - the read below would simply be re-evaluated - but Plasma's map of
    // values has no change signal for the keys a settings dialog writes, so
    // `recheck()` is the only way a running widget learns that the file moved.
    function test_configured_language_reaches_the_widget() {
        stored.language = "kk"
        bridge.recheck()
        compare(bridge.language, "kk", "the bridge resolved it")
        compare(Loc.configuredLanguage, "kk", "the bridge handed the value over")
        compare(Loc.language, "kk", "resolved to a catalog")
        compare(liveLabel.text, T.translate("kk", "Settings"), "and the widget is in it")

        stored.language = "de"
        bridge.recheck()
        compare(bridge.language, "de", "a later change follows without a restart")
        compare(liveLabel.text, T.translate("de", "Settings"))

        // Re-asking a value that did not move must not disturb anything: the
        // popup does this on every single click.
        var before = Loc.configuredLanguage
        bridge.recheck()
        bridge.recheck()
        compare(Loc.configuredLanguage, before, "an unchanged re-read changes nothing")
    }

    // A key the configuration reports itself - which is what a settings dialog
    // saving a language does, its write landing in the same property map the
    // widget reads: the new language arrives without anyone opening anything.
    function test_a_change_the_configuration_reports_arrives_at_once() {
        stored.language = "de"
        compare(bridge.language, "de", "the bridge followed the report")
        compare(Loc.configuredLanguage, "de", "the bridge handed it over")
        compare(liveLabel.text, T.translate("de", "Settings"), "and the widget is in it")
    }

    // A saved language the widget cannot have written itself: a code with a
    // region, or one no catalog covers. Neither may leave the widget languageless.
    function test_a_saved_value_is_read_as_a_language() {
        stored.language = "zh-Hans-CN"
        bridge.recheck()
        compare(Loc.language, "zh", "a language tag finds the catalog it belongs to")

        stored.language = "system"
        bridge.recheck()
        compare(Loc.language, Loc.systemLanguage, "and 'system' means the system language")

        stored.language = ""
        bridge.recheck()
        compare(Loc.language, Loc.systemLanguage, "as does nothing saved at all")
    }

    function test_a_bridge_with_nothing_to_read_stays_quiet() {
        stored.language = "kk"
        bridge.recheck()
        compare(quietBridge.speaks, false, "a page's bridge has no source")
        quietBridge.refresh()
        compare(Loc.configuredLanguage, "kk", "and it leaves the language alone")
    }

    // The language of a dialog is the language its page was opened with, which
    // is not necessarily the one already in the file - and the file's own value
    // returns the moment the dialog lets go of it.
    function test_a_page_hands_over_the_language_it_shows() {
        stored.language = "de"
        bridge.recheck()
        compare(Loc.configuredLanguage, "de")

        bridge.pendingLanguage = "ru"
        compare(Loc.configuredLanguage, "ru", "what the dialog shows wins over what is stored")

        bridge.pendingLanguage = ""
        compare(Loc.configuredLanguage, "de", "and the stored language returns when the dialog closes")
    }
}
