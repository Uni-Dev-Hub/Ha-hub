import QtQuick
import QtQuick.LocalStorage
import QtWebSockets
import org.kde.plasma.plasmoid
import "../code/ha_client.js" as HAClient
import "../code/ha_helpers.js" as HAHelpers
import "../code/ha_storage.js" as HAStorage

Item {
    id: manager

    property string host: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.host || "") : ""
    property int port: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.port || 8123) : 8123
    property bool useSsl: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.useSsl || false) : false
    property string accessToken: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.accessToken || "") : ""
    property string serverName: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.serverName || "Home Assistant") : "Home Assistant"

    property string state: "DISCONNECTED"
    property string connectionStatus: i18n("Disconnected")
    property bool isConnected: false
    property bool autoReconnectAllowed: true

    property bool _isManualDisconnecting: false

    property var entities: ({})
    property var _entitiesLowerMap: ({})

    property int entitiesRevision: 0
    property var discoveredServers: []
    property var userDevicesList: []

    readonly property alias mdns: mdns
    readonly property bool isSearching: mdns ? mdns.isSearching : false

    property var areasList: []
    property var devicesList: []
    property var devicesListFormatted: []
    property var entityToAreaMap: ({})
    property var entityToDeviceMap: ({})
    property var deviceToEntitiesMap: ({})
    property var entityRegistryMap: ({})

    property int _getConfigMsgId: 0
    property int _getStatesMsgId: 0
    property int _getAreasMsgId: 0
    property int _getDevicesMsgId: 0
    property int _getEntityRegMsgId: 0

    property var _tempDeviceToAreaMap: ({})
    property var _customMsgHandlers: ({})
    property int _globalMsgIdCounter: 100

    function getNextMessageId() {
        manager._globalMsgIdCounter++;
        return manager._globalMsgIdCounter;
    }

    function registerStatsHandler(msgId, callback) {
        _customMsgHandlers[msgId] = callback;
    }

    function _updateCredentials(h, p, t, s, name) {
        if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) {
            try {
                if (h !== undefined) Plasmoid.configuration.host = h;
                if (p !== undefined) Plasmoid.configuration.port = p;
                if (t !== undefined) Plasmoid.configuration.accessToken = t;
                if (s !== undefined) Plasmoid.configuration.useSsl = s;
                if (name !== undefined) Plasmoid.configuration.serverName = name;
            } catch (e) {}
        } else {
            if (h !== undefined) host = h;
            if (p !== undefined) port = p;
            if (t !== undefined) accessToken = t;
            if (s !== undefined) useSsl = s;
            if (name !== undefined) serverName = name;
        }
    }

    function loadSharedCredentials() {
        if (accessToken && accessToken.length > 0) return true;
        var loaded = HAStorage.loadSharedCredentials(LocalStorage, host, port, serverName);
        if (loaded) {
            manager._updateCredentials(loaded.host, loaded.port, loaded.accessToken, loaded.useSsl, loaded.serverName);
            return true;
        }
        return false;
    }

    function saveSharedCredentials() {
        HAStorage.saveSharedCredentials(LocalStorage, host, port, accessToken, useSsl, serverName);
    }

    function isSecondaryEntity(entId) {
        return HAHelpers.isSecondaryEntity(entId);
    }

    function getPrimaryEntityForDevice(devEnts) {
        if (!devEnts || devEnts.length === 0) return "";
        var controlDomains = [
            "switch", "light", "climate", "fan", "cover", "lock",
            "outlet", "valve", "media_player", "vacuum", "water_heater",
            "humidifier", "siren", "camera", "alarm_control_panel", "input_boolean"
        ];

        for (var c = 0; c < controlDomains.length; c++) {
            var cDom = controlDomains[c];
            for (var i = 0; i < devEnts.length; i++) {
                var entId = devEnts[i];
                if (entId.split(".")[0] === cDom) {
                    if (manager.isSecondaryEntity(entId)) continue;
                    var isConfigOrDiag = manager.entityRegistryMap && manager.entityRegistryMap[entId] &&
                        manager.entityRegistryMap[entId].category !== null &&
                        manager.entityRegistryMap[entId].category !== undefined;
                    if (!isConfigOrDiag) return entId;
                }
            }
        }

        for (var c2 = 0; c2 < controlDomains.length; c2++) {
            var cDom2 = controlDomains[c2];
            for (var j = 0; j < devEnts.length; j++) {
                var entId2 = devEnts[j];
                if (entId2.split(".")[0] === cDom2) {
                    if (!manager.isSecondaryEntity(entId2)) return entId2;
                }
            }
        }

        var diagnosticFallback = "";
        for (var s = 0; s < devEnts.length; s++) {
            var entId3 = devEnts[s];
            var d2 = entId3.split(".")[0];
            if (d2 === "sensor" || d2 === "binary_sensor") {
                if (manager.isSecondaryEntity(entId3)) continue;
                var isDiag = manager.entityRegistryMap && manager.entityRegistryMap[entId3] &&
                    (manager.entityRegistryMap[entId3].category === "diagnostic" || manager.entityRegistryMap[entId3].category === "config");
                if (!isDiag) return entId3;
                if (!diagnosticFallback) diagnosticFallback = entId3;
            }
        }
        if (diagnosticFallback) return diagnosticFallback;

        for (var f = 0; f < devEnts.length; f++) {
            if (!manager.isSecondaryEntity(devEnts[f])) return devEnts[f];
        }

        return devEnts[0];
    }

    function _buildFormattedDevices() {
        var rawDevs = manager.devicesList || [];
        var devToEnts = manager.deviceToEntitiesMap || {};
        var formatted = [];

        for (var i = 0; i < rawDevs.length; i++) {
            var dev = rawDevs[i];
            if (!dev || !dev.id || !dev.name || dev.name.trim().length === 0) continue;
            if (dev.disabled_by !== null && dev.disabled_by !== undefined) continue;

            var devEnts = devToEnts[dev.id] || [];
            var primaryEnt = manager.getPrimaryEntityForDevice(devEnts);

            formatted.push({
                id: dev.id,
                name: dev.name_by_user || dev.name,
                model: dev.model || "",
                manufacturer: dev.manufacturer || "",
                sw_version: dev.sw_version || "",
                area_id: dev.area_id || "",
                primaryEntity: primaryEnt,
                entityCount: devEnts.length,
                entities: devEnts
            });
        }
        manager.devicesListFormatted = formatted;
        manager._buildUserDevicesList();
    }

    function _buildUserDevicesList() {
        var result = [];
        var seen = {};

        if (devicesListFormatted && devicesListFormatted.length > 0) {
            for (var d = 0; d < devicesListFormatted.length; d++) {
                var dev = devicesListFormatted[d];
                if (dev && dev.primaryEntity) {
                    seen[dev.primaryEntity] = true;
                    result.push(dev.primaryEntity);
                }
            }
        }

        var helperDomains = ["input_boolean", "scene", "script"];
        if (entities) {
            var keys = Object.keys(entities);
            for (var k = 0; k < keys.length; k++) {
                var entKey = keys[k];
                if (seen[entKey]) continue;
                var devId = manager.entityToDeviceMap ? manager.entityToDeviceMap[entKey] : null;
                if (devId) continue;
                var dom = entKey.split(".")[0];
                if (helperDomains.indexOf(dom) !== -1) {
                    seen[entKey] = true;
                    result.push(entKey);
                }
            }
        }

        result.sort(function(a, b) {
            var entObjA = manager.getEntity(a);
            var devIdA = manager.entityToDeviceMap ? (manager.entityToDeviceMap[a] || "") : "";
            var titleA = HAHelpers.getDeviceTitle(a, entObjA, devIdA, manager);

            var entObjB = manager.getEntity(b);
            var devIdB = manager.entityToDeviceMap ? (manager.entityToDeviceMap[b] || "") : "";
            var titleB = HAHelpers.getDeviceTitle(b, entObjB, devIdB, manager);

            titleA = (titleA || a).toString().trim();
            titleB = (titleB || b).toString().trim();

            return titleA.localeCompare(titleB, undefined, { numeric: true, sensitivity: "base" });
        });

        manager.userDevicesList = result;
    }

    Timer {
        id: revisionDebounceTimer
        interval: 50
        repeat: false
        onTriggered: {
            manager.entitiesRevision++;
        }
    }

    function _notifyEntitiesChanged() {
        manager._buildUserDevicesList();
        if (!revisionDebounceTimer.running) {
            revisionDebounceTimer.start();
        }
    }

    Timer {
        id: connTimeoutTimer
        interval: 7000
        repeat: false
        onTriggered: {
            if (manager.state === "AUTHENTICATING" || manager.state === "DISCOVERING") {
                console.warn("HA-hub: Connection timed out for host:", manager.host);
                manager.disconnectFromHA();
                manager.state = "ERROR";
                manager.connectionStatus = i18n("Error: Connection timed out for %1", manager.host);
                if (manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                    autoReconnectTimer.start();
                }
            }
        }
    }

    Timer {
        id: autoReconnectTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (!manager.isConnected && manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                manager._connectSocket();
            }
        }
    }

    MDNSDiscovery {
        id: mdns
        onDiscoveryFinished: function(serverList) {
            connTimeoutTimer.stop();
            manager.discoveredServers = serverList;
            if (serverList.length > 0) {
                manager.connectionStatus = i18n("Found devices: %1", serverList.length);
            } else {
                manager.connectionStatus = i18n("No devices found in local network");
            }
        }
    }

    WebSocket {
        id: webSocket
        active: false

        onStatusChanged: function() {
            if (webSocket.status === WebSocket.Error) {
                connTimeoutTimer.stop();
                var err = webSocket.errorString || i18n("Unable to connect to server");
                if (manager.useSsl && (err.indexOf("wrong version number") !== -1 || err.indexOf("SSL routines") !== -1 || err.indexOf("handshake") !== -1)) {
                    manager.connectionStatus = i18n("SSL Error: HA server is running without SSL. Uncheck 'SSL (wss://)'");
                } else {
                    manager.connectionStatus = i18n("Error: %1", err);
                }
                manager.state = "ERROR";
                manager.isConnected = false;
                if (manager.autoReconnectAllowed) autoReconnectTimer.start();
            } else if (webSocket.status === WebSocket.Closed) {
                connTimeoutTimer.stop();

                if (manager._isManualDisconnecting) {
                    manager._isManualDisconnecting = false;
                    return;
                }

                if (manager.state !== "ERROR") {
                    manager.state = "DISCONNECTED";
                    manager.connectionStatus = i18n("Disconnected");
                }
                manager.isConnected = false;
                if (manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                    autoReconnectTimer.start();
                }
            }
        }

        onTextMessageReceived: function(message) {
            manager._handleIncomingMessage(message);
        }
    }

    function safeSend(messageText) {
        if (webSocket && webSocket.status === WebSocket.Open) {
            webSocket.sendTextMessage(messageText);
        }
    }

    function getEntity(id) {
        if (!id || !entities) return null;
        var cleanId = HAHelpers.cleanEntityId(id);
        if (entities[cleanId]) return entities[cleanId];
        var lower = cleanId.toLowerCase();
        if (_entitiesLowerMap[lower]) return _entitiesLowerMap[lower];
        return null;
    }

    function getDeviceRaw(deviceId) {
        if (!deviceId || !devicesList) return null;
        for (var i = 0; i < devicesList.length; i++) {
            if (devicesList[i].id === deviceId) return devicesList[i];
        }
        return null;
    }

    function _connectSocket() {
        if (!accessToken || accessToken.length === 0) {
            state = "ERROR";
            connectionStatus = i18n("Please enter Access Token");
            return;
        }

        _isManualDisconnecting = true;
        webSocket.active = false;

        connTimeoutTimer.restart();
        state = "AUTHENTICATING";
        connectionStatus = i18n("Connecting to %1:%2...", host, port);

        var protocol = useSsl ? "wss://" : "ws://";
        var targetUrl = protocol + host + ":" + port + "/api/websocket";

        webSocket.url = targetUrl;
        webSocket.active = true;
    }

    function startAutoConnect() {
        manager.loadSharedCredentials();
        if (host && host.length > 0 && accessToken && accessToken.length > 0) {
            manager._connectSocket();
        } else {
            manager.runAutoDiscovery();
        }
    }

    function runAutoDiscovery() {
        if (mdns && mdns.isSearching) return;
        manager.discoveredServers = [];
        connectionStatus = i18n("Searching for servers in network...");
        mdns.startDiscovery(host);
    }

    function connectWithParams(newHost, newPort, newToken, ssl) {
        autoReconnectTimer.stop();
        if (mdns) mdns.stopDiscovery();

        var cleanHost = newHost ? newHost.toString().trim() : "";
        cleanHost = cleanHost.replace(/^https?:\/\//i, "").replace(/^wss?:\/\//i, "");
        if (cleanHost.indexOf("/") !== -1) cleanHost = cleanHost.split("/")[0];
        if (cleanHost.indexOf(":") !== -1) {
            var parts = cleanHost.split(":");
            cleanHost = parts[0];
            if (parts[1] && parseInt(parts[1])) newPort = parseInt(parts[1]);
        }

        var h = cleanHost && cleanHost.length > 0 ? cleanHost : "homeassistant.local";
        var p = newPort > 0 ? newPort : 8123;
        var t = newToken ? newToken.trim() : "";
        var s = !!ssl;

        manager._updateCredentials(h, p, t, s, undefined);
        manager._connectSocket();
    }

    function disconnectFromHA() {
        autoReconnectTimer.stop();
        connTimeoutTimer.stop();
        _isManualDisconnecting = true;
        webSocket.active = false;
        state = "DISCONNECTED";
        connectionStatus = i18n("Disconnected");
        isConnected = false;
    }

    function callService(domain, service, entityId, serviceData) {
        if (!isConnected) return;
        var msgId = manager.getNextMessageId();
        var payload = HAClient.buildCallServicePayload(msgId, domain, service, serviceData || {}, entityId);
        manager.safeSend(payload);
    }

    function _handleIncomingMessage(rawMessage) {
        var parsed = HAClient.parseIncomingMessage(rawMessage);
        if (!parsed.success) return;
        var msg = parsed.data;

        if (msg.type === "ping") {
            manager.safeSend(JSON.stringify({ type: "pong", id: msg.id }));
            return;
        }
        if (msg.type === "auth_required") {
            manager.safeSend(HAClient.buildAuthPayload(accessToken));
            return;
        }
        if (msg.type === "auth_ok") {
            connTimeoutTimer.stop();
            autoReconnectTimer.stop();
            isConnected = true;
            state = "CONNECTED";
            connectionStatus = i18n("Connected");
            manager.saveSharedCredentials();
            manager._subscribeToEvents();
            manager._fetchInitialStates();
            manager._fetchRegistries();
            return;
        }
        if (msg.type === "auth_invalid") {
            connTimeoutTimer.stop();
            autoReconnectTimer.stop();
            state = "ERROR";
            connectionStatus = i18n("Invalid Access Token");
            manager.disconnectFromHA();
            return;
        }

        if (msg.id && _customMsgHandlers[msg.id]) {
            var callback = _customMsgHandlers[msg.id];
            delete _customMsgHandlers[msg.id];
            if (msg.success && msg.result !== undefined) {
                callback(msg.result);
            } else {
                callback(null);
            }
            return;
        }

        if (msg.type === "event" && msg.event && msg.event.event_type === "state_changed") {
            var eventData = msg.event.data;
            if (eventData && eventData.entity_id && eventData.new_state) {
                var entId = eventData.entity_id;
                manager.entities[entId] = eventData.new_state;
                manager._entitiesLowerMap[entId.toLowerCase()] = eventData.new_state;
                manager._notifyEntitiesChanged();
            }
            return;
        }

        if (msg.type === "result" && msg.id === _getConfigMsgId && msg.success && msg.result) {
            if (msg.result.location_name) {
                manager._updateCredentials(undefined, undefined, undefined, undefined, msg.result.location_name);
                manager.saveSharedCredentials();
            }
            return;
        }

        if (msg.type === "result" && msg.id === _getStatesMsgId && msg.success && msg.result) {
            var temp = {};
            var tempLower = {};
            var list = msg.result;
            if (list && typeof list.length === "number") {
                for (var i = 0; i < list.length; i++) {
                    if (list[i] && list[i].entity_id) {
                        var eId = list[i].entity_id;
                        temp[eId] = list[i];
                        tempLower[eId.toLowerCase()] = list[i];
                    }
                }
            }
            manager.entities = temp;
            manager._entitiesLowerMap = tempLower;
            manager._notifyEntitiesChanged();
            return;
        }

        if (msg.type === "result" && msg.id === _getAreasMsgId && msg.success && msg.result) {
            manager.areasList = msg.result || [];
            manager._notifyEntitiesChanged();
            return;
        }

        if (msg.type === "result" && msg.id === _getDevicesMsgId && msg.success && msg.result) {
            var devs = msg.result || [];
            var devToArea = {};
            manager.devicesList = devs;
            for (var d = 0; d < devs.length; d++) {
                if (devs[d].id && devs[d].area_id) {
                    devToArea[devs[d].id] = devs[d].area_id;
                }
            }
            manager._tempDeviceToAreaMap = devToArea;
            manager._buildFormattedDevices();

            _getEntityRegMsgId = manager.getNextMessageId();
            manager.safeSend(HAClient.buildGetEntityRegistryPayload(_getEntityRegMsgId));
            return;
        }

        if (msg.type === "result" && msg.id === _getEntityRegMsgId && msg.success && msg.result) {
            var entReg = msg.result || [];
            var entToArea = {};
            var entToDev = {};
            var devToEnts = {};
            var regMap = {};

            for (var e = 0; e < entReg.length; e++) {
                var item = entReg[e];
                if (item.entity_id) {
                    var isDisabled = (item.disabled_by !== null && item.disabled_by !== undefined);
                    var isHidden = (item.hidden_by !== null && item.hidden_by !== undefined);

                    regMap[item.entity_id] = {
                        disabled: isDisabled,
                        hidden: isHidden,
                        category: item.entity_category || null
                    };

                    if (isDisabled || isHidden) continue;

                    var areaId = item.area_id || (item.device_id ? manager._tempDeviceToAreaMap[item.device_id] : null);
                    if (areaId) entToArea[item.entity_id] = areaId;
                    if (item.device_id) {
                        entToDev[item.entity_id] = item.device_id;
                        if (!devToEnts[item.device_id]) devToEnts[item.device_id] = [];
                        devToEnts[item.device_id].push(item.entity_id);
                    }
                }
            }
            manager.entityRegistryMap = regMap;
            manager.entityToAreaMap = entToArea;
            manager.entityToDeviceMap = entToDev;
            manager.deviceToEntitiesMap = devToEnts;
            manager._buildFormattedDevices();
            manager._notifyEntitiesChanged();
            return;
        }
    }

    function _subscribeToEvents() {
        manager.safeSend(HAClient.buildSubscribeEventsPayload(manager.getNextMessageId()));
    }

    function _fetchInitialStates() {
        _getConfigMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetConfigPayload(_getConfigMsgId));

        _getStatesMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetStatesPayload(_getStatesMsgId));
    }

    function _fetchRegistries() {
        _getAreasMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetAreasPayload(_getAreasMsgId));

        _getDevicesMsgId = manager.getNextMessageId();
        manager.safeSend(HAClient.buildGetDevicesPayload(_getDevicesMsgId));
    }
}
