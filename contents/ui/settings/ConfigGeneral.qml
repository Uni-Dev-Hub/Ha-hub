pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: generalSettings
    title: i18n("General")
    topPadding: 0

    // cfg_* properties are bound to the kcfg entries by the Plasma 6
    // configuration backend. Declared values only act as fallback defaults.
    property string cfg_host: "homeassistant.local"
    property int cfg_port: 8123
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_autoConnect: true
    property string cfg_serverName: "Home Assistant"
    property bool cfg_showHiddenEntities: false
    property bool cfg_showDiagnosticEntities: false

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true

        Controls.TextField {
            id: hostField
            Kirigami.FormData.label: i18n("HA Host / IP:")
            placeholderText: "homeassistant.local or 192.168.1.100"
            text: generalSettings.cfg_host
            Layout.fillWidth: true
            onTextEdited: generalSettings.cfg_host = text
        }

        Controls.TextField {
            id: portField
            Kirigami.FormData.label: i18n("Port:")
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
            Kirigami.FormData.label: i18n("SSL Connection:")
            text: i18n("Use wss://")
            checked: generalSettings.cfg_useSsl
            onToggled: generalSettings.cfg_useSsl = checked
        }

        Controls.TextField {
            id: tokenField
            Kirigami.FormData.label: i18n("Access Token:")
            placeholderText: "Long-Lived Access Token"
            text: generalSettings.cfg_accessToken
            echoMode: TextInput.Password
            Layout.fillWidth: true
            onTextEdited: generalSettings.cfg_accessToken = text
        }

        Controls.Label {
            visible: generalSettings.cfg_accessToken.length === 0
            text: i18n("A previously saved token is kept in the widget's private storage and used automatically. Enter a new token here only to replace it.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.italic: true
            opacity: Kirigami.Theme.disabledTextColor.a
            Kirigami.FormData.isEdgeToEdge: true
        }

        Controls.CheckBox {
            id: autoConnectCheckBox
            Kirigami.FormData.label: i18n("Auto Connect:")
            text: i18n("Connect on startup")
            checked: generalSettings.cfg_autoConnect
            onToggled: generalSettings.cfg_autoConnect = checked
        }

        Controls.CheckBox {
            id: showHiddenCheckBox
            Kirigami.FormData.label: i18n("Device List:")
            text: i18n("Show hidden entities")
            checked: generalSettings.cfg_showHiddenEntities
            onToggled: generalSettings.cfg_showHiddenEntities = checked
        }

        Controls.CheckBox {
            id: showDiagnosticCheckBox
            Kirigami.FormData.label: i18n("Device List:")
            text: i18n("Show diagnostic / config entities")
            checked: generalSettings.cfg_showDiagnosticEntities
            onToggled: generalSettings.cfg_showDiagnosticEntities = checked
        }
    }
}
