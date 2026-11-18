pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../../l10n"

Kirigami.ScrollablePage {
    id: generalSettings
    title: Loc.t("General")
    topPadding: 0

    // cfg_* properties are bound to the kcfg entries by the Plasma 6
    // configuration backend. Declared values only act as fallback defaults.
    property string cfg_host: "homeassistant.local"
    property int cfg_port: 8123
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_autoConnect: true
    property string cfg_language: "system"
    property string cfg_serverName: "Home Assistant"
    property bool cfg_showHiddenEntities: false
    property bool cfg_showDiagnosticEntities: false

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true

        Controls.TextField {
            id: hostField
            Kirigami.FormData.label: Loc.t("HA Host / IP:")
            placeholderText: "homeassistant.local or 192.168.1.100"
            text: generalSettings.cfg_host
            Layout.fillWidth: true
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
            onTextEdited: generalSettings.cfg_accessToken = text
        }

        Controls.Label {
            visible: generalSettings.cfg_accessToken.length === 0
            text: Loc.t("A previously saved token is kept in the widget's private storage and used automatically. Enter a new token here only to replace it.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
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
            Kirigami.FormData.label: Loc.t("Language:")
            Layout.fillWidth: true
            readonly property var modelItems: [{ code: "system", label: Loc.t("System language") }].concat(Loc.languages)
            model: modelItems
            textRole: "label"
            currentIndex: {
                for (var i = 0; i < modelItems.length; i++) {
                    if (modelItems[i].code === generalSettings.cfg_language) return i;
                }
                return 0;
            }
            onActivated: generalSettings.cfg_language = modelItems[currentIndex].code
        }

        Controls.CheckBox {
            id: showHiddenCheckBox
            Kirigami.FormData.label: Loc.t("Device List:")
            text: Loc.t("Show hidden entities")
            checked: generalSettings.cfg_showHiddenEntities
            onToggled: generalSettings.cfg_showHiddenEntities = checked
        }

        Controls.CheckBox {
            id: showDiagnosticCheckBox
            Kirigami.FormData.label: Loc.t("Device List:")
            text: Loc.t("Show diagnostic / config entities")
            checked: generalSettings.cfg_showDiagnosticEntities
            onToggled: generalSettings.cfg_showDiagnosticEntities = checked
        }
    }
}
