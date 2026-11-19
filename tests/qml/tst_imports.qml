import QtQuick
import QtTest
import "../../contents/l10n"

// Regression test for "Type X unavailable" / "Script file ... unavailable"
// runtime errors: every file in the main UI chain must link cleanly,
// including its relative JS imports and nested types.
TestCase {
    name: "ComponentLinking"

    property var chain: [
        "../../contents/ui/main.qml",
        "../../contents/ui/FullRepresentation.qml",
        "../../contents/ui/CompactRepresentation.qml",
        "../../contents/ui/views/DeviceListView.qml",
        "../../contents/ui/views/DashboardView.qml",
        "../../contents/ui/views/AuthWizardView.qml",
        "../../contents/ui/views/HeaderView.qml",
        "../../contents/ui/components/DashboardCard.qml",
        "../../contents/ui/components/DeviceCard.qml",
        "../../contents/ui/components/EntityFilterBar.qml",
        "../../contents/ui/components/EntityPickerField.qml",
        "../../contents/ui/components/MarqueeLabel.qml",
        "../../contents/ui/components/NativeDeviceItem.qml",
        "../../contents/ui/details/DeviceDetailsPage.qml",
        "../../contents/ui/settings/ConfigGeneral.qml",
        "../../contents/ui/settings/ConfigAppearance.qml",
        "../../contents/ui/settings/ConfigFavorites.qml",
        "../../contents/ui/settings/ConfigDashboard.qml",
        "../../contents/config/config.qml",
        "../../contents/ui/details/sections/AlarmControlPanelSection.qml",
        "../../contents/ui/details/sections/BinarySensorSection.qml",
        "../../contents/ui/details/sections/CameraSection.qml",
        "../../contents/ui/details/sections/ClimateSensorSection.qml",
        "../../contents/ui/details/sections/CoverSection.qml",
        "../../contents/ui/details/sections/DeviceChannelsSection.qml",
        "../../contents/ui/details/sections/DeviceInfoSection.qml",
        "../../contents/ui/details/sections/DeviceOptionsSection.qml",
        "../../contents/ui/details/sections/FanSection.qml",
        "../../contents/ui/details/sections/GenericSection.qml",
        "../../contents/ui/details/sections/HistorySection.qml",
        "../../contents/ui/details/sections/HumidifierSection.qml",
        "../../contents/ui/details/sections/LawnMowerSection.qml",
        "../../contents/ui/details/sections/LightSection.qml",
        "../../contents/ui/details/sections/LockSection.qml",
        "../../contents/ui/details/sections/MediaPlayerSection.qml",
        "../../contents/ui/details/sections/PersonSection.qml",
        "../../contents/ui/details/sections/PlugSection.qml",
        "../../contents/ui/details/sections/SirenSection.qml",
        "../../contents/ui/details/sections/SwitchSection.qml",
        "../../contents/ui/details/sections/ThermostatSection.qml",
        "../../contents/ui/details/sections/VacuumSection.qml",
        "../../contents/ui/details/sections/ValveSection.qml",
        "../../contents/ui/details/sections/WaterHeaterSection.qml",
        "../../contents/ui/details/sections/WeatherSection.qml"
    ]

    function test_all_ui_components_link() {
        var failures = []
        for (var i = 0; i < chain.length; i++) {
            var url = Qt.resolvedUrl(chain[i])
            var comp = Qt.createComponent(url, Component.Asynchronous)
            var waited = 0
            while (comp.status === Component.Loading && waited < 5000) {
                wait(25)
                waited += 25
            }
            if (comp.status !== Component.Ready) {
                failures.push(chain[i] + " => " + comp.errorString())
            }
        }
        compare(failures.join("\n"), "")
    }

    // Collect every text rendered inside an object tree.
    function collectTexts(item, out) {
        if (!item) return out
        if (typeof item.text === "string" && item.text.length > 0) out.push(item.text)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) collectTexts(kids[i], out)
        return out
    }

    // Linking a component does not evaluate its bindings, so a view that
    // forgets `import "../../l10n"` still links but throws
    // "Loc is not defined" as soon as it is created. Instantiate the empty
    // dashboard state and check a translated string really reached the screen.
    function test_views_render_localized_text() {
        var comp = Qt.createComponent(Qt.resolvedUrl("../../contents/ui/views/DashboardView.qml"))
        compare(comp.status, Component.Ready, comp.errorString())
        var view = comp.createObject(null, { cardsJson: "[]", columns: 2, cardSize: "compact" })
        verify(!!view)
        wait(50)
        var texts = collectTexts(view, [])
        verify(texts.indexOf(Loc.t("Open Settings")) !== -1,
               "dashboard empty state renders no localized text: " + JSON.stringify(texts))
        view.destroy()
    }
}
