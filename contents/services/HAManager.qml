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
    // Bumped only when the *set* of listed entities changes (not on every state update)
    property int listsRevision: 0
    property int entityCount: 0
    property var _deviceById: ({})
    property bool _listsDirty: true
    property int _reconnectAttempts: 0
    property bool _awaitingPong: false
    property int _pingMsgId: 0
    property var discoveredServers: []
    property var userDevicesList: []
    property var lightsAndSwitchesList: []
    property var climateAndSensorsList: []
    property var mediaAndOthersList: []
    property var allEntitiesList: []

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

    function _buildCategorizedLists() {
        var allKeys = manager.entities ? Object.keys(manager.entities) : [];
        var lights = [];
        var sensors = [];
        var media = [];
        var all = [];

        var lightDomains = ["light", "switch", "outlet", "fan", "input_boolean"];
        var sensorDomains = ["sensor", "binary_sensor", "climate", "air_quality", "humidifier", "weather", "water_heater"];
        var mediaDomains = ["media_player", "vacuum", "cover", "lock", "valve", "scene", "script", "camera", "button", "input_button",
                            "siren", "alarm_control_panel", "lawn_mower", "person"];
        var skipDomains = ["zone", "persistent_notification", "sun", "update", "tts", "stt", "conversation", "event",
                           "image", "todo", "wake_word", "assist_satellite", "ai_task", "notify", "tag"];
        var reg = manager.entityRegistryMap || {};

        for (var i = 0; i < allKeys.length; i++) {
            var entId = allKeys[i];
            var dom = entId.split(".")[0];

            if (skipDomains.indexOf(dom) !== -1) continue;
            var r = reg[entId];
            if (r && (r.hidden || r.disabled || r.category === "diagnostic" || r.category === "config")) continue;

            all.push(entId);

            if (lightDomains.indexOf(dom) !== -1) {
                lights.push(entId);
            } else if (sensorDomains.indexOf(dom) !== -1) {
                sensors.push(entId);
            } else if (mediaDomains.indexOf(dom) !== -1) {
                media.push(entId);
            }
        }

        // Precompute titles once: sorting 700+ entities with lookups inside the comparator is slow
        var titles = {};
        for (var t = 0; t < all.length; t++) {
            titles[all[t]] = HAHelpers.getEntityTitle(all[t], manager.entities[all[t]]).toString().trim().toLowerCase();
        }
        function sortList(list) {
            return list.sort(function(a, b) {
                return titles[a].localeCompare(titles[b], undefined, { numeric: true, sensitivity: "base" });
            });
        }

        manager.lightsAndSwitchesList = sortList(lights);
        manager.climateAndSensorsList = sortList(sensors);
        manager.mediaAndOthersList = sortList(media);
        manager.allEntitiesList = sortList(all);
        manager.entityCount = all.length;
        manager._listsDirty = false;
        manager.listsRevision++;
    }

    Timer {
        id: revisionDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (manager._listsDirty) {
                manager._buildUserDevicesList();
                manager._buildCategorizedLists();
            }
            manager.entitiesRevision++;
        }
    }

    function _notifyEntitiesChanged(structural) {
        if (structural) manager._listsDirty = true;
        if (!revisionDebounceTimer.running) {
            revisionDebounceTimer.start();
        }
    }

    Timer {
        id: pingTimer
        interval: 25000
        repeat: true
        running: manager.isConnected
        onTriggered: {
            if (!manager.isConnected || webSocket.status !== WebSocket.Open) return;
            if (manager._awaitingPong) {
                // Previous ping never answered: the connection is dead
                console.warn("HA-hub: no pong received, reconnecting");
                manager._awaitingPong = false;
                manager._dropAndReconnect(i18n("Connection lost, reconnecting…"));
                return;
            }
            manager._awaitingPong = true;
            manager._pingMsgId = manager.getNextMessageId();
            manager.safeSend(JSON.stringify({ id: manager._pingMsgId, type: "ping" }));
        }
    }

    // Close the socket without the "manual" flag so the normal reconnect path runs
    function _dropAndReconnect(statusText) {
        connTimeoutTimer.stop();
        manager.isConnected = false;
        manager.state = "ERROR";
        manager.connectionStatus = statusText;
        if (webSocket.status === WebSocket.Open || webSocket.status === WebSocket.Connecting) {
            manager._isManualDisconnecting = true;
            webSocket.active = false;
        }
        manager._scheduleReconnect();
    }

    // Exponential backoff: 3s, 6s, 12s … capped at 60s
    function _scheduleReconnect() {
        if (!manager.autoReconnectAllowed || !manager.accessToken || manager.accessToken.length === 0) return;
        if (autoReconnectTimer.running) return; // Error is often followed by Closed
        var delay = Math.min(60000, 3000 * Math.pow(2, manager._reconnectAttempts));
        manager._reconnectAttempts++;
        autoReconnectTimer.interval = delay;
        autoReconnectTimer.restart();
        manager.connectionStatus = i18n("%1 Retrying in %2 s", manager.connectionStatus.replace(/ Nuovo tentativo.*$/, ""), Math.round(delay / 1000));
    }

    function reconnect() {
        manager._reconnectAttempts = 0;
        manager.disconnectFromHA();
        manager.startAutoConnect();
    }

    function refreshStates() {
        if (!manager.isConnected) {
            manager.reconnect();
            return;
        }
        manager._listsDirty = true;
        manager._fetchInitialStates();
        manager._fetchRegistries();
    }

    Timer {
        id: connTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (manager.state === "AUTHENTICATING" || manager.state === "DISCOVERING") {
                console.warn("HA-hub: Connection timed out for host:", manager.host);
                manager._dropAndReconnect(i18n("Connection to %1 timed out.", manager.host));
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
                manager.connectionStatus = i18n("Servers found: %1", serverList.length);
            } else {
                manager.connectionStatus = i18n("No servers found on the local network");
            }
        }
    }

    WebSocket {
        id: webSocket
        active: false

        onStatusChanged: function() {
            if (webSocket.status === WebSocket.Open) {
                manager._isManualDisconnecting = false;
            } else if (webSocket.status === WebSocket.Error) {
                connTimeoutTimer.stop();
                var err = webSocket.errorString || i18n("Unable to reach the server");
                var msg;
                if (manager.useSsl && (err.indexOf("wrong version number") !== -1 || err.indexOf("SSL routines") !== -1 || err.indexOf("handshake") !== -1)) {
                    msg = i18n("SSL error: the server does not use SSL. Disable “wss://”.");
                } else {
                    msg = i18n("Error: %1.", err);
                }
                manager.state = "ERROR";
                manager.isConnected = false;
                manager.connectionStatus = msg;
                manager._scheduleReconnect();
            } else if (webSocket.status === WebSocket.Closed) {
                connTimeoutTimer.stop();

                if (manager._isManualDisconnecting) {
                    manager._isManualDisconnecting = false;
                    return;
                }

                if (manager.state !== "ERROR") {
                    manager.state = "DISCONNECTED";
                    manager.connectionStatus = i18n("Connection closed.");
                }
                manager.isConnected = false;
                manager._scheduleReconnect();
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
        if (!deviceId) return null;
        return _deviceById[deviceId] || null;
    }

    function _connectSocket() {
        if (!accessToken || accessToken.length === 0) {
            state = "ERROR";
            connectionStatus = i18n("Please enter the access token");
            return;
        }

        // Only expect a Closed event if a socket is actually open; otherwise the
        // flag would stay set and swallow the next real disconnect (no auto-reconnect).
        if (webSocket.status === WebSocket.Open || webSocket.status === WebSocket.Connecting) {
            _isManualDisconnecting = true;
        }
        webSocket.active = false;
        _awaitingPong = false;

        connTimeoutTimer.restart();
        state = "AUTHENTICATING";
        connectionStatus = i18n("Connecting to %1:%2…", host, port);

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
        connectionStatus = i18n("Searching for servers on the network…");
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
        if (webSocket.status === WebSocket.Open || webSocket.status === WebSocket.Connecting) {
            _isManualDisconnecting = true;
        }
        webSocket.active = false;
        _awaitingPong = false;
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

        if (msg.type === "pong") {
            manager._awaitingPong = false;
            return;
        }
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
            _reconnectAttempts = 0;
            _awaitingPong = false;
            _listsDirty = true;
            manager.saveSharedCredentials();
            manager._subscribeToEvents();
            manager._fetchInitialStates();
            manager._fetchRegistries();
            return;
        }
        if (msg.type === "auth_invalid") {
            connTimeoutTimer.stop();
            autoReconnectTimer.stop();
            manager.disconnectFromHA();
            state = "ERROR";
            connectionStatus = i18n("Invalid access token");
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
            if (eventData && eventData.entity_id) {
                var entId = eventData.entity_id;
                var old = manager.entities[entId];
                if (!eventData.new_state) {
                    delete manager.entities[entId];
                    delete manager._entitiesLowerMap[entId.toLowerCase()];
                    manager._notifyEntitiesChanged(true);
                } else {
                    manager.entities[entId] = eventData.new_state;
                    manager._entitiesLowerMap[entId.toLowerCase()] = eventData.new_state;
                    var oldName = old && old.attributes ? old.attributes.friendly_name : undefined;
                    var newName = eventData.new_state.attributes ? eventData.new_state.attributes.friendly_name : undefined;
                    manager._notifyEntitiesChanged(!old || oldName !== newName);
                }
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
            manager._notifyEntitiesChanged(true);
            return;
        }

        if (msg.type === "result" && msg.id === _getAreasMsgId && msg.success && msg.result) {
            manager.areasList = msg.result || [];
            manager._notifyEntitiesChanged(true);
            return;
        }

        if (msg.type === "result" && msg.id === _getDevicesMsgId && msg.success && msg.result) {
            var devs = msg.result || [];
            var devToArea = {};
            var byId = {};
            for (var b = 0; b < devs.length; b++) {
                if (devs[b] && devs[b].id) byId[devs[b].id] = devs[b];
            }
            manager._deviceById = byId;
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
            manager._notifyEntitiesChanged(true);
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
