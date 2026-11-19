pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "../../l10n"

Kirigami.ScrollablePage {
    id: appearancePage
    title: Loc.t("Appearance")
    topPadding: Kirigami.Units.smallSpacing

    // cfg_* properties are bound to the kcfg entries by the Plasma 6
    // configuration backend. Declared values only act as fallback defaults.
    property bool cfg_showDashboard: false
    property bool cfg_showDevices: true

    // Which views the popup offers. With a single view the tab bar (and with
    // it the switch button) disappears and the popup opens that view directly.
    readonly property int enabledViewCount:
        (appearancePage.cfg_showDashboard ? 1 : 0) + (appearancePage.cfg_showDevices ? 1 : 0)

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
}
