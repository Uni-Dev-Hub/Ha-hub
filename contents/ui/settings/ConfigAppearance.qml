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

    // cfg_* properties are bound to the kcfg entries by the Plasma 6
    // configuration backend. Declared values only act as fallback defaults.
    property bool cfg_showDashboard: false
    property bool cfg_showDevices: true
    property string cfg_headerPersonEntityId: ""
    property string cfg_headerEntityId: ""
    property bool cfg_headerEntityLabel: false
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

    Component.onCompleted: headerManager.startAutoConnect()

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

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Item {
                Kirigami.FormData.label: Loc.t("Popup Header:")
                Kirigami.FormData.isSection: true
            }

            Item {
                Kirigami.FormData.label: Loc.t("User picture:")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

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
            }

            Item {
                Kirigami.FormData.label: Loc.t("Value next to greeting:")

                Components.EntityPickerField {
                    Layout.fillWidth: true
                    haManager: headerManager
                    value: appearancePage.cfg_headerEntityId
                    onEntityPicked: function(entityId) {
                        appearancePage.cfg_headerEntityId = entityId;
                    }
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
    }
}
