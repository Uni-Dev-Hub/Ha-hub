pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../services" as Services
import "../components" as Components
import "../../code/ha_helpers.mjs" as HAHelpers
import "../../l10n"

Kirigami.ScrollablePage {
    id: appearancePage
    title: Loc.t("Appearance")
    topPadding: Kirigami.Units.smallSpacing

    // This dialog has its own Loc instance: without the bridge every page here
    // would stay in the system language no matter what is configured.
    Components.LanguageBridge {
        // Handed over where Plasma lets a settings page see the configuration
        // at all; a page normally cannot, and then the language is saved the
        // Plasma way - through the cfg_ property and Apply.
        configuration: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
            ? Plasmoid.configuration : null
    }

    // cfg_* properties are bound to the kcfg entries by the Plasma 6
    // configuration backend. Declared values only act as fallback defaults.
    property bool cfg_showDashboard: false
    property bool cfg_showDevices: true
    property string cfg_headerPersonEntityId: ""
    property string cfg_headerEntityId: ""
    property bool cfg_headerEntityLabel: false
    property string cfg_trayIconMode: "auto"
    property string cfg_trayIconName: ""
    property string cfg_trayIconPath: ""
    property string cfg_host: "homeassistant.local"
    property string cfg_port: "8123"
    property bool cfg_useSsl: false

    // Which views the popup offers. With a single view the tab bar (and with
    // it the switch button) disappears and the popup opens that view directly.
    readonly property int enabledViewCount:
        (appearancePage.cfg_showDashboard ? 1 : 0) + (appearancePage.cfg_showDevices ? 1 : 0)

    // Only needed to offer entity pickers for the header.
    Services.HAManager {
        id: headerManager
        host: appearancePage.cfg_host
        port: parseInt(appearancePage.cfg_port) || 8123
        useSsl: appearancePage.cfg_useSsl
    }

    // The settings dialog builds its pages up front; connecting a full
    // WebSocket + entity catalogue for a page the user never opened made the
    // whole dialog sluggish, so each page connects only once it is actually
    // shown for the first time.
    property bool managerStarted: false

    function maybeStartManager() {
        if (managerStarted) return;
        managerStarted = true;
        headerManager.startAutoConnect();
    }

    Component.onCompleted: if (visible) maybeStartManager()
    onVisibleChanged: if (visible) maybeStartManager()

    readonly property var personChoice: [{ id: "", name: Loc.t("Auto (first person with a picture)") }]
        .concat(headerManager.personOptions)

    readonly property string headerPreviewText: {
        var id = appearancePage.cfg_headerEntityId;
        if (!headerManager.isConnected || !id) return "";
        var rev = headerManager.entitiesRevision;
        return HAHelpers.getEntityHeaderValue(id, headerManager.getEntity(id), headerManager,
            Loc.language, appearancePage.cfg_headerEntityLabel);
    }

    readonly property int personIndex: {
        for (var i = 0; i < personChoice.length; i++) {
            if (personChoice[i].id === appearancePage.cfg_headerPersonEntityId) return i;
        }
        return 0;
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        width: parent.width

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Controls.CheckBox {
                id: dashboardViewCheck
                Kirigami.FormData.label: Loc.t("Views in popup:")
                text: Loc.t("Show 'Dashboard' tab")
                checked: appearancePage.cfg_showDashboard
                // Turning the only remaining view off would leave an empty popup.
                enabled: !checked || appearancePage.cfg_showDevices
                onToggled: appearancePage.cfg_showDashboard = checked
            }

            Controls.CheckBox {
                id: devicesViewCheck
                text: Loc.t("Show 'Devices' tab")
                checked: appearancePage.cfg_showDevices
                enabled: !checked || appearancePage.cfg_showDashboard
                onToggled: appearancePage.cfg_showDevices = checked
            }

            PlasmaComponents3.Label {
                visible: appearancePage.enabledViewCount < 2
                text: Loc.t("Only one view is shown, so the switch button between Dashboard and Devices is hidden.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // Section headings live outside the forms: Kirigami.FormLayout has no
        // section concept, and a zero-height placeholder Item inside it made
        // the following fields overlap (the bug this rewrite fixes).
        PlasmaComponents3.Label {
            text: Loc.t("Popup Header:")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.05
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            // Combo plus its hint as one real Layout cell: the FormLayout can
            // measure it, so the label on the left lines up with its centre.
            ColumnLayout {
                Kirigami.FormData.label: Loc.t("User picture:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                spacing: Kirigami.Units.smallSpacing * 0.6

                Controls.ComboBox {
                    id: personCombo
                    Layout.fillWidth: true
                    enabled: headerManager.isConnected
                    model: appearancePage.personChoice
                    textRole: "name"
                    currentIndex: appearancePage.personIndex
                    onActivated: {
                        var item = model[currentIndex];
                        appearancePage.cfg_headerPersonEntityId = item ? item.id : "";
                    }
                }

                PlasmaComponents3.Label {
                    text: Loc.t("The picture comes from the selected person in Home Assistant. Nothing is shown when that person has no picture.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Components.EntityPickerField {
                Kirigami.FormData.label: Loc.t("Value next to greeting:")
                Layout.fillWidth: true
                haManager: headerManager
                value: appearancePage.cfg_headerEntityId
                onEntityPicked: function(entityId) {
                    appearancePage.cfg_headerEntityId = entityId;
                }
            }

            Controls.CheckBox {
                text: Loc.t("Show the entity name in front of the value")
                enabled: appearancePage.cfg_headerEntityId.length > 0
                checked: appearancePage.cfg_headerEntityLabel
                onToggled: appearancePage.cfg_headerEntityLabel = checked
            }

            PlasmaComponents3.Label {
                visible: headerManager.isConnected && appearancePage.cfg_headerEntityId.length > 0
                text: Loc.t("Preview") + ": " + appearancePage.headerPreviewText
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents3.Label {
            text: Loc.t("Widget Icon:")
            font.bold: true
            font.pointSize: Qt.application.font.pointSize * 1.05
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Kirigami.FormData.label: Loc.t("Panel and tray:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                spacing: Kirigami.Units.smallSpacing * 0.6

                Components.IconPickerField {
                    Layout.fillWidth: true
                    mode: appearancePage.cfg_trayIconMode
                    iconName: appearancePage.cfg_trayIconName
                    iconPath: appearancePage.cfg_trayIconPath
                    connected: headerManager.isConnected
                    onIconChanged: {
                        appearancePage.cfg_trayIconMode = mode;
                        appearancePage.cfg_trayIconName = iconName;
                        appearancePage.cfg_trayIconPath = iconPath;
                    }
                }

                PlasmaComponents3.Label {
                    text: Loc.t("The custom picture is loaded from its file, so keep it where it will not be deleted.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }
}
