import QtQuick
import QtTest

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
        "../../contents/ui/components/MarqueeLabel.qml",
        "../../contents/ui/components/NativeDeviceItem.qml",
        "../../contents/ui/details/DeviceDetailsPage.qml",
        "../../contents/ui/settings/ConfigGeneral.qml",
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
}
