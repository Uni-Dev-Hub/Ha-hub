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
    readonly property string cfg_viewModeDefault: "rows"
    readonly property int cfg_cornerRadiusDefault: 16
    readonly property int cfg_backgroundOpacityDefault: 70

    property string cfg_host: "192.168.1.100"
    property string cfg_port: "8123"
    property bool cfg_useSsl: false
    property string cfg_accessToken: ""
    property bool cfg_autoConnect: true
    property string cfg_serverName: "Home Assistant"
    property string cfg_favoriteEntities: "[]"
    property string cfg_viewMode: "rows"
    property int cfg_cornerRadius: 16
    property int cfg_backgroundOpacity: 70
    // Keys edited elsewhere; declared so the config dialog doesn't warn
    property int cfg_lastTab
    property int cfg_lastTabDefault
    property int cfg_panelDisplayMode
    property int cfg_panelDisplayModeDefault
    property string cfg_primarySensorEntity
    property string cfg_primarySensorEntityDefault
    property string cfg_desktopEntityId
    property string cfg_desktopEntityIdDefault
    property bool cfg_showDashboard
    property bool cfg_showDashboardDefault

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Home Assistant connection")
            Kirigami.FormData.isSection: true
        }

        Controls.TextField {
            id: hostField
            Kirigami.FormData.label: i18n("Home Assistant host / IP:")
            placeholderText: "homeassistant.local or 192.168.1.100"
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
            Kirigami.FormData.label: i18n("Secure connection:")
            text: i18n("Use wss:// (HTTPS)")
            checked: generalSettings.cfg_useSsl
            onToggled: generalSettings.cfg_useSsl = checked
        }

        Controls.TextField {
            id: tokenField
            Kirigami.FormData.label: i18n("Long-lived access token:")
            placeholderText: i18n("Long-lived token (Profile → Security in Home Assistant)")
            text: generalSettings.cfg_accessToken
            echoMode: TextInput.Password
            Layout.fillWidth: true
            onTextEdited: generalSettings.cfg_accessToken = text
        }

        Controls.CheckBox {
            id: autoConnectCheckBox
            Kirigami.FormData.label: i18n("Auto-connect:")
            text: i18n("Connect on startup")
            checked: generalSettings.cfg_autoConnect
            onToggled: generalSettings.cfg_autoConnect = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Appearance")
            Kirigami.FormData.isSection: true
        }

        Controls.ComboBox {
            id: viewModeBox
            Kirigami.FormData.label: i18n("Default view:")
            model: [
                { text: i18n("Rows"), value: "rows" },
                { text: i18n("Tiles"), value: "tiles" },
                { text: i18n("Cards (Liquid Glass)"), value: "cards" }
            ]
            textRole: "text"
            valueRole: "value"
            currentIndex: {
                if (generalSettings.cfg_viewMode === "tiles") return 1;
                if (generalSettings.cfg_viewMode === "cards") return 2;
                return 0;
            }
            onActivated: {
                generalSettings.cfg_viewMode = model[currentIndex].value;
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Corner radius:")
            spacing: Kirigami.Units.smallSpacing

            Controls.Slider {
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
                from: 0
                to: 32
                stepSize: 1
                value: generalSettings.cfg_cornerRadius
                onMoved: generalSettings.cfg_cornerRadius = Math.round(value)
            }
            Controls.SpinBox {
                from: 0
                to: 32
                value: generalSettings.cfg_cornerRadius
                textFromValue: function(v) { return v + " px"; }
                valueFromText: function(t) { return parseInt(t); }
                onValueModified: generalSettings.cfg_cornerRadius = value
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")
            spacing: Kirigami.Units.smallSpacing

            Controls.Slider {
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 8
                from: 0
                to: 100
                stepSize: 5
                value: generalSettings.cfg_backgroundOpacity
                onMoved: generalSettings.cfg_backgroundOpacity = Math.round(value)
            }
            Controls.SpinBox {
                from: 0
                to: 100
                stepSize: 5
                value: generalSettings.cfg_backgroundOpacity
                textFromValue: function(v) { return v + " %"; }
                valueFromText: function(t) { return parseInt(t); }
                onValueModified: generalSettings.cfg_backgroundOpacity = value
            }
        }

        Controls.Label {
            text: i18n("Corner radius and opacity apply when the widget is on the desktop; in a panel, Plasma draws the popup frame. Colors always follow the system theme.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
