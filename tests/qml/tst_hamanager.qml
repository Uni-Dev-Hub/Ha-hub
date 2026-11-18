import QtQuick
import QtTest
import "../../contents/services" as Services

TestCase {
    name: "HAManagerCatalog"

    Services.HAManager {
        id: manager
    }

    function init() {
        manager.entities = {
            "switch.gang_1": { entity_id: "switch.gang_1", state: "on", attributes: { friendly_name: "Gang 1" } },
            "switch.gang_2": { entity_id: "switch.gang_2", state: "off", attributes: { friendly_name: "Gang 2" } },
            "switch.template_switch": { entity_id: "switch.template_switch", state: "on", attributes: { friendly_name: "Template Switch" } },
            "light.standalone": { entity_id: "light.standalone", state: "on", attributes: { friendly_name: "Standalone Light" } },
            "sensor.temperature": { entity_id: "sensor.temperature", state: "21.5", attributes: { friendly_name: "Temperature", unit_of_measurement: "°C" } }
        };

        manager.devicesList = [
            { id: "dev1", name: "Multi Gang", name_by_user: null, area_id: "kitchen" }
        ];
        manager.areasList = [
            { area_id: "kitchen", name: "Kitchen", floor_id: "ground" }
        ];
        manager.floorsList = [
            { floor_id: "ground", name: "Ground floor" }
        ];
        manager.entityRegistryMap = {
            "switch.gang_1": { deviceId: "dev1", areaId: "", name: "", originalName: "", category: null, hidden: false, disabled: false, labels: [] },
            "switch.gang_2": { deviceId: "dev1", areaId: "", name: "", originalName: "", category: null, hidden: false, disabled: false, labels: [] }
        };
        manager.entityToDeviceMap = {
            "switch.gang_1": "dev1",
            "switch.gang_2": "dev1"
        };
        manager.entityToAreaMap = {};
        manager.deviceToEntitiesMap = {
            "dev1": ["switch.gang_1", "switch.gang_2"]
        };

        manager._rebuildLookupMaps()
        manager._buildEntityCatalog()
    }

    function test_all_selectable_entities_are_in_catalog() {
        compare(manager.entityCatalog.length, 5)
        verify(manager.userDevicesList.indexOf("switch.gang_1") !== -1)
        verify(manager.userDevicesList.indexOf("switch.gang_2") !== -1)
        verify(manager.userDevicesList.indexOf("switch.template_switch") !== -1)
        verify(manager.userDevicesList.indexOf("light.standalone") !== -1)
        verify(manager.userDevicesList.indexOf("sensor.temperature") !== -1)
    }

    function test_multi_gang_device_keeps_both_channels() {
        compare(manager.deviceGroups.length, 1)
        compare(manager.deviceGroups[0].entityIds.length, 2)
        verify(manager.deviceGroups[0].entityIds.indexOf("switch.gang_1") !== -1)
        verify(manager.deviceGroups[0].entityIds.indexOf("switch.gang_2") !== -1)
    }

    function test_standalone_entities_are_in_area_group() {
        var unassigned = null
        for (var i = 0; i < manager.areaGroups.length; i++) {
            if (!manager.areaGroups[i].areaId) unassigned = manager.areaGroups[i]
        }
        verify(unassigned !== null)
        verify(unassigned.entityIds.indexOf("switch.template_switch") !== -1)
        verify(unassigned.entityIds.indexOf("light.standalone") !== -1)
    }

    function test_catalog_title_follows_state_change() {
        compare(manager.getCatalogEntry("light.standalone").name, "Standalone Light")

        var evt = JSON.stringify({
            type: "event",
            event: {
                event_type: "state_changed",
                data: {
                    entity_id: "light.standalone",
                    new_state: { entity_id: "light.standalone", state: "on", attributes: { friendly_name: "Renamed Light" } }
                }
            }
        })
        manager._handleIncomingMessage(evt)

        var entry = manager.getCatalogEntry("light.standalone")
        verify(entry !== null)
        compare(entry.name, "Renamed Light")
    }

    function test_catalog_drops_removed_entities() {
        var evt = JSON.stringify({
            type: "event",
            event: {
                event_type: "state_changed",
                data: { entity_id: "light.standalone", new_state: null }
            }
        })
        manager._handleIncomingMessage(evt)

        verify(manager.getEntity("light.standalone") === null)
        verify(manager.getCatalogEntry("light.standalone") === null)
    }

    function test_pending_handlers_fail_on_disconnect() {
        var called = 0
        var reason = ""
        manager._customMsgHandlers[99991] = function(result, success, error) {
            called++
            reason = success ? "" : error
        }

        manager.disconnectFromHA()

        compare(called, 1)
        compare(reason, "disconnected")
        verify(Object.keys(manager._customMsgHandlers).indexOf("99991") === -1)
    }

    function test_send_request_fails_when_disconnected() {
        var called = 0
        var gotError = ""
        var msgId = manager.sendRequest(JSON.stringify({ id: 99992, type: "get_states" }), function(result, success, error) {
            called++
            gotError = error
        })

        compare(msgId, 0)
        compare(called, 1)
        compare(gotError, "not_connected")
    }
}
