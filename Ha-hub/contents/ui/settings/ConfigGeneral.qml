pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: generalSettings
    title: i18n("General")
    topPadding: 0

    readonly property string cfg_hostDefault: "192.168.1.100"
    readonly property string cfg_portDefault: "8123"
    readonly property bool cfg_useSslDefault: false
    readonly property string cfg_accessTokenDefault: ""
    readonly property bool cfg_autoConnectDefault: true
    readonly property string cfg_serverNameDefault: "Home Assistant"
    readonly property string cfg_favoriteEntitiesDefault: "[]"

    property string cfg_host: "192.168.1.100"
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_autoConnect: true
    property string cfg_serverName: "Home Assistant"
    property string cfg_favoriteEntities: "[]"

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true

        Controls.TextField {
            id: hostField
            Kirigami.FormData.label: i18n("HA Host / IP:")
            placeholderText: "192.168.1.100 or homeassistant.local"
            text: generalSettings.cfg_host
            Layout.fillWidth: true
            onTextEdited: generalSettings.cfg_host = text
        }

        Controls.TextField {
            id: portField
            Kirigami.FormData.label: i18n("Port:")
            placeholderText: "8123"
            text: generalSettings.cfg_port
            inputMethodHints: Qt.ImhDigitsOnly
            onTextEdited: generalSettings.cfg_port = text
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

        Controls.CheckBox {
            id: autoConnectCheckBox
            Kirigami.FormData.label: i18n("Auto Connect:")
            text: i18n("Connect on startup")
            checked: generalSettings.cfg_autoConnect
            onToggled: generalSettings.cfg_autoConnect = checked
        }
    }
}
