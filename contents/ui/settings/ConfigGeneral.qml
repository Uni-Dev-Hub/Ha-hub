pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../components" as Components
import "../../l10n"

Kirigami.ScrollablePage {
    id: generalSettings
    // The page's own heading. Plasma assigns a title of its own when it opens a
    // page - the category name it read *before* this page's bridge had set the
    // language, from a copy made while the dialog was still in the system
    // language - and an assignment breaks the binding, so the heading of the
    // first page opened kept that language. Re-asserting it here, and whenever
    // the language moves, puts the right one back.
    readonly property string pageTitle: Loc.t("General")
    title: pageTitle
    onPageTitleChanged: generalSettings.title = generalSettings.pageTitle
    topPadding: 0

    // This dialog has its own Loc instance: without a language pushed into it
    // every page here stays in the system language. A settings page is a file
    // of its own, and Plasma's `Plasmoid` lives in the applet's context, not in
    // one a page can reach - so the bridge is given the configuration when it
    // happens to be reachable, and the language this page was opened with
    // (cfg_language, which the dialog always hands over) seeds the dialog below.
    Components.LanguageBridge {
        id: settingsLanguageBridge
        configuration: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
            ? Plasmoid.configuration : null
    }

    // cfg_* properties are values the Plasma 6 configuration backend hands a
    // page when it opens it; declared values only act as fallback defaults.
    // The fallback for the language is the language this dialog is showing,
    // never a hard-coded "system": whatever this page holds is what Apply writes
    // out, and a wrong "system" here silently erases a chosen language.
    property string cfg_host: "homeassistant.local"
    property int cfg_port: 8123
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_autoConnect: true
    property string cfg_language: Loc.configuredLanguage
    property string cfg_serverName: "Home Assistant"
    property bool cfg_showHiddenEntities: false
    property bool cfg_showDiagnosticEntities: false

    // A pick assigns the picker's currentIndex, as the control's own delegate
    // does, and that drops the currentIndex binding - so keep the control
    // pointing at whatever the page holds instead. The dialog follows the same
    // property: the first change is not a pick at all, it is the saved language
    // arriving with the page, and that is what the dialog should be showing.
    onCfg_languageChanged: {
        Loc.configuredLanguage = cfg_language
        if (!languageCombo) return
        languageCombo.currentIndex = languageCombo.indexForCode(cfg_language)
    }

    // One way to change the language, used by the picker (and by the tests):
    // straight into the configuration through the bridge, so the choice is
    // saved and reaches the widget at once, and into cfg_language, so the
    // dialog still knows there is something to apply. The language is the one
    // setting that applies on pick rather than on Apply - Apply cannot undo a
    // language the user is already reading.
    // One writer for the language: the page. The settings dialog keeps a copy of
    // the configuration of its own, and a write that goes around it - straight
    // into the applet's configuration, however tempting - leaves that copy
    // holding the old value, which the dialog then writes back over the choice
    // when it closes. So the language travels the way every other setting does:
    // in cfg_language, which Apply copies. The running widget still picks it up
    // at once, because the bridge watches the configuration Apply writes to.
    function selectLanguage(code) {
        if (code === generalSettings.cfg_language && Loc.configuredLanguage === code) return
        generalSettings.cfg_language = code
    }

    // How wide a row of the form below may ask to be. Kirigami sizes a form to
    // the widest thing it holds, and a hint line that may wrap asks for the
    // width of its whole text in one line - the form took that for its columns,
    // and the fields, their labels and their text ran past the window and were
    // cut off. What is bounded here is everything the form has no other measure
    // by; the allowance covers the column of labels, and the floor keeps a
    // field usable in a window dragged narrow.
    readonly property real formFieldWidth: Math.max(Kirigami.Units.gridUnit * 12,
        availableWidth - Kirigami.Units.gridUnit * 22)

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true

        Controls.TextField {
            id: hostField
            Kirigami.FormData.label: Loc.t("HA Host / IP:")
            placeholderText: "homeassistant.local or 192.168.1.100"
            text: generalSettings.cfg_host
            Layout.fillWidth: true
            Layout.preferredWidth: generalSettings.formFieldWidth
            onTextEdited: generalSettings.cfg_host = text
        }

        Controls.TextField {
            id: portField
            Kirigami.FormData.label: Loc.t("Port:")
            placeholderText: "8123"
            text: String(generalSettings.cfg_port)
            inputMethodHints: Qt.ImhDigitsOnly
            onTextEdited: {
                var parsed = parseInt(text);
                if (!isNaN(parsed) && parsed > 0 && parsed <= 65535) {
                    generalSettings.cfg_port = parsed;
                }
            }
        }

        Controls.CheckBox {
            id: sslCheckBox
            Kirigami.FormData.label: Loc.t("SSL Connection:")
            text: Loc.t("Use wss://")
            checked: generalSettings.cfg_useSsl
            onToggled: generalSettings.cfg_useSsl = checked
        }

        Controls.TextField {
            id: tokenField
            Kirigami.FormData.label: Loc.t("Access Token:")
            placeholderText: "Long-Lived Access Token"
            text: generalSettings.cfg_accessToken
            echoMode: TextInput.Password
            Layout.fillWidth: true
            Layout.preferredWidth: generalSettings.formFieldWidth
            onTextEdited: generalSettings.cfg_accessToken = text
        }

        Controls.Label {
            visible: generalSettings.cfg_accessToken.length === 0
            text: Loc.t("A previously saved token is kept in the widget's private storage and used automatically. Enter a new token here only to replace it.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.preferredWidth: generalSettings.formFieldWidth
            font.italic: true
            opacity: 0.65
        }

        Controls.CheckBox {
            id: autoConnectCheckBox
            Kirigami.FormData.label: Loc.t("Auto Connect:")
            text: Loc.t("Connect on startup")
            checked: generalSettings.cfg_autoConnect
            onToggled: generalSettings.cfg_autoConnect = checked
        }

        Controls.ComboBox {
            id: languageCombo
            objectName: "languageCombo"
            Kirigami.FormData.label: Loc.t("Language:")
            Layout.fillWidth: true
            Layout.preferredWidth: generalSettings.formFieldWidth

            // The model carries only what never changes: the codes and the
            // names each language writes about itself. A translated string
            // inside the model would rebuild the model at the very moment the
            // language changes (the picker retranslates as it picks), and the
            // control resets its currentIndex when the model is swapped.
            readonly property var entries: [{ code: "system" }].concat(Loc.languages)
            readonly property string systemLabel: Loc.t("System language")
            model: entries
            textRole: "code"

            function labelFor(code) {
                if (code === "system") return languageCombo.systemLabel
                var langs = Loc.languages
                for (var i = 0; i < langs.length; ++i) {
                    if (langs[i].code === code) return langs[i].label
                }
                return code
            }
            function indexForCode(code) {
                for (var i = 0; i < entries.length; ++i) {
                    if (entries[i].code === code) return i
                }
                return 0
            }

            currentIndex: indexForCode(generalSettings.cfg_language)
            // Translated on its own, so switching language retranslates the
            // button and the list without touching the model.
            displayText: currentIndex >= 0 && currentIndex < entries.length
                ? languageCombo.labelFor(entries[currentIndex].code) : ""

            delegate: Controls.ItemDelegate {
                required property var modelData
                required property int index
                width: languageCombo.width
                text: languageCombo.labelFor(modelData.code)
                highlighted: languageCombo.highlightedIndex === index
                onClicked: {
                    // A pick is a pick, wherever it came from. Writing popup.closed
                    // used to live here, and since that property is read-only the
                    // assignment threw a TypeError that stopped the handler before
                    // the language was ever handed over: the list looked dead.
                    languageCombo.currentIndex = index
                    languageCombo.popup.dismiss()
                    generalSettings.selectLanguage(modelData.code)
                }
            }

            // Keyboard navigation in the popup ends here instead of in a delegate
            // click. selectLanguage ignores a pick of the language already set.
            onActivated: (index) => generalSettings.selectLanguage(entries[index].code)
        }

        // The language is applied the moment it is picked, but like every other
        // setting it is only stored on Apply - and a page cannot store it
        // itself: the configuration lives in the applet's context, not in one a
        // settings page can reach. Say so, rather than let the user find out
        // when the dialog is closed.
        PlasmaComponents3.Label {
            text: Loc.t("Apply to keep this language after closing the settings.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.preferredWidth: generalSettings.formFieldWidth
        }

        Controls.CheckBox {
            id: showHiddenCheckBox
            Kirigami.FormData.label: Loc.t("Device List:")
            text: Loc.t("Show hidden entities")
            checked: generalSettings.cfg_showHiddenEntities
            onToggled: generalSettings.cfg_showHiddenEntities = checked
        }

        // The two belong together, so only the first of them is labelled and
        // the second sits under it in the column of fields. Labelled twice, the
        // page read the same heading out twice for two different settings.
        Controls.CheckBox {
            id: showDiagnosticCheckBox
            text: Loc.t("Show diagnostic / config entities")
            checked: generalSettings.cfg_showDiagnosticEntities
            onToggled: generalSettings.cfg_showDiagnosticEntities = checked
        }
    }
}
