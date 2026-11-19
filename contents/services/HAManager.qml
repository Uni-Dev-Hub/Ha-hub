import QtQuick
import QtQuick.LocalStorage
import QtWebSockets
import org.kde.plasma.plasmoid
// Registers the KDE Loc.t() global; also required when this component is
// instantiated outside the Plasma shell (e.g. qmltestrunner).
import org.kde.plasma.core
import "../code/ha_client.js" as HAClient
import "../code/ha_helpers.mjs" as HAHelpers
import "../code/ha_storage.js" as HAStorage
import "../l10n"

Item {
    id: manager

    property string host: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.host || "") : ""
    property int port: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.port || 8123) : 8123
    property bool useSsl: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.useSsl || false) : false
    property string serverName: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.serverName || "Home Assistant") : "Home Assistant"

    // Token storage policy: the Long-Lived Access Token lives in ONE place,
    // the shared LocalStorage DB (HAStorage), so every HA-Hub instance can
    // use it and no plaintext copy is left in plasmarc. Plasmoid.configuration
    // is only a transport for freshly typed tokens (settings page / wizard);
    // it is wiped as soon as the token has been persisted. KWallet is not
    // available to pure-QML applets on Plasma 6, this is the best we can do
    // without shipping a C++ extension.
    property string _configToken: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.accessToken || "") : ""
    property string _sharedToken: ""
    property string accessToken: manager._sharedToken.length > 0 ? manager._sharedToken : manager._configToken

    on_ConfigTokenChanged: {
        // A token arrived through kcfg (settings page apply): adopt it and
        // move it into the shared store right away.
        if (manager._configToken.length > 0) {
            manager._sharedToken = manager._configToken;
            if (manager.isConnected) manager.saveSharedCredentials();
        }
    }

    property string state: "DISCONNECTED"
    property string connectionStatus: Loc.t("Disconnected")
    property bool isConnected: false
    property bool autoReconnectAllowed: true
    property bool autoConnect: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.autoConnect !== false) : true

    property bool _isManualDisconnecting: false
    property int _reconnectAttempts: 0
    property real _lastRxMs: 0

    property var entities: ({})
    property var _entitiesLowerMap: ({})

    property int entitiesRevision: 0
    property var discoveredServers: []
    property var userDevicesList: []

    readonly property alias mdns: mdns
    readonly property bool isSearching: mdns ? mdns.isSearching : false

    property var areasList: []
    property var floorsList: []
    property var labelsList: []
    property var devicesList: []
    property var devicesListFormatted: []
    property var entityToAreaMap: ({})
    property var entityToDeviceMap: ({})
    property var deviceToEntitiesMap: ({})
    property var entityRegistryMap: ({})

    // Read-only registry catalog. It is built from entity states + entity/device/
    // area/floor/label registries and is the single source of truth for every
    // device/entity list in the UI.
    property var entityCatalog: []
    property var deviceGroups: []
    property var areaGroups: []
    property var servicesMap: ({})

    property var _deviceById: ({})
    property var _areaById: ({})
    property var _floorById: ({})
    property var _labelById: ({})
    property var _catalogById: ({})
    property int _catalogEntityCount: -1

    property bool includeHiddenEntities: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.showHiddenEntities || false) : false
    property bool includeDiagnosticEntities: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) ? (Plasmoid.configuration.showDiagnosticEntities || false) : false

    onIncludeHiddenEntitiesChanged: {
        if (manager.entities && Object.keys(manager.entities).length > 0) {
            manager._buildEntityCatalog();
            manager._notifyEntitiesChanged();
        }
    }
    onIncludeDiagnosticEntitiesChanged: {
        if (manager.entities && Object.keys(manager.entities).length > 0) {
            manager._buildEntityCatalog();
            manager._notifyEntitiesChanged();
        }
    }

    property var _tempDeviceToAreaMap: ({})
    property var _customMsgHandlers: ({})
    property int _globalMsgIdCounter: 100
    property bool _registryRefreshPending: false

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
                // The token never goes into plasmarc; it lives in the shared
                // in-memory/store layer (_sharedToken) only.
                if (t !== undefined) manager._sharedToken = t;
                if (s !== undefined) Plasmoid.configuration.useSsl = s;
                if (name !== undefined) Plasmoid.configuration.serverName = name;
            } catch (e) {}
        } else {
            if (h !== undefined) host = h;
            if (p !== undefined) port = p;
            if (t !== undefined) manager._sharedToken = t;
            if (s !== undefined) useSsl = s;
            if (name !== undefined) serverName = name;
        }
    }

    function loadSharedCredentials() {
        if (manager.accessToken.length > 0) return true;
        var loaded = HAStorage.loadSharedCredentials(LocalStorage, host, port, serverName);
        if (loaded) {
            manager._updateCredentials(loaded.host, loaded.port, undefined, loaded.useSsl, loaded.serverName);
            manager._sharedToken = loaded.accessToken;
            return true;
        }
        return false;
    }

    function saveSharedCredentials() {
        if (manager.accessToken.length === 0) return false;
        manager._sharedToken = manager.accessToken;
        var saved = HAStorage.saveSharedCredentials(LocalStorage, host, port, manager._sharedToken, useSsl, serverName);
        // Single-store policy: drop the plaintext copy from plasmarc once the
        // shared store has the token.
        if (saved && typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) {
            try {
                if (Plasmoid.configuration.accessToken !== "") Plasmoid.configuration.accessToken = "";
            } catch (e) {}
        }
        return saved;
    }

    function isSecondaryEntity(entId) {
        return HAHelpers.isSecondaryEntity(entId, manager.entityRegistryMap ? manager.entityRegistryMap[entId] : null);
    }

    function _isEntityHiddenOrDisabled(entry) {
        if (!entry) return true;
        if (entry.disabled) return true;
        if (entry.hidden && !manager.includeHiddenEntities) return true;
        if (entry.category === "diagnostic" && !manager.includeDiagnosticEntities) return true;
        if (entry.category === "config" && !manager.includeDiagnosticEntities) return true;
        return false;
    }

    function getPrimaryEntityForDevice(devEnts) {
        if (!devEnts || devEnts.length === 0) return "";
        var controlDomains = HAHelpers.CONTROL_DOMAINS;

        for (var c = 0; c < controlDomains.length; c++) {
            var cDom = controlDomains[c];
            for (var i = 0; i < devEnts.length; i++) {
                var entId = devEnts[i];
                if (entId.split(".")[0] !== cDom) continue;

                var reg = manager.entityRegistryMap ? manager.entityRegistryMap[entId] : null;
                if (manager.isSecondaryEntity(entId)) continue;
                if (reg && (reg.category === "config" || reg.category === "diagnostic")) continue;
                return entId;
            }
        }

        var diagnosticFallback = "";
        for (var s = 0; s < devEnts.length; s++) {
            var entId3 = devEnts[s];
            var d2 = entId3.split(".")[0];
            if (d2 !== "sensor" && d2 !== "binary_sensor") continue;
            if (manager.isSecondaryEntity(entId3)) continue;
            var isDiag = manager.entityRegistryMap && manager.entityRegistryMap[entId3] &&
                (manager.entityRegistryMap[entId3].category === "diagnostic" || manager.entityRegistryMap[entId3].category === "config");
            if (!isDiag) return entId3;
            if (!diagnosticFallback) diagnosticFallback = entId3;
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
            if (!dev || !dev.id) continue;
            if (dev.disabled_by !== null && dev.disabled_by !== undefined) continue;

            var devEnts = devToEnts[dev.id] || [];
            var primaryEnt = manager.getPrimaryEntityForDevice(devEnts);
            var fallbackName = primaryEnt ? HAHelpers.getEntityFriendlyName(primaryEnt, manager.getEntity(primaryEnt), manager.entityRegistryMap ? manager.entityRegistryMap[primaryEnt] : null) : dev.id;

            formatted.push({
                id: dev.id,
                name: HAHelpers.getDeviceDisplayName(dev, fallbackName),
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
    }

    function _buildEntityCatalog() {
        var list = [];
        var byId = {};
        var keys = entities ? Object.keys(entities) : [];

        for (var i = 0; i < keys.length; i++) {
            var id = keys[i];
            if (!HAHelpers.isSelectableEntity(id)) continue;

            var ent = entities[id];
            if (!ent) continue;

            var reg = manager.entityRegistryMap ? manager.entityRegistryMap[id] : null;
            var domain = HAHelpers.getDomain(id);
            var deviceId = (reg && reg.deviceId) || (manager.entityToDeviceMap ? (manager.entityToDeviceMap[id] || "") : "");
            var dev = manager.getDeviceRaw(deviceId);
            var deviceName = HAHelpers.getDeviceDisplayName(dev, "");

            var areaId = (reg && reg.areaId)
                || (manager.entityToAreaMap ? (manager.entityToAreaMap[id] || "") : "")
                || (dev && dev.area_id)
                || "";
            var area = manager.getAreaRaw(areaId);
            var areaName = area ? (area.name || "") : "";
            var floorId = area ? (area.floor_id || area.floorId || "") : "";
            var floor = manager.getFloorRaw(floorId);
            var floorName = floor ? (floor.name || "") : "";

            var name = HAHelpers.getEntityTitle(id, ent, reg, manager);
            var category = (reg && reg.category) || null;

            var entry = {
                id: id,
                entityId: id,
                name: name || id,
                domain: domain,
                deviceId: deviceId,
                deviceName: deviceName,
                areaId: areaId,
                areaName: areaName,
                floorId: floorId,
                floorName: floorName,
                labels: (reg && reg.labels) ? reg.labels : [],
                category: category,
                hidden: !!(reg && reg.hidden),
                disabled: !!(reg && reg.disabled),
                isConfig: category === "config",
                isDiagnostic: category === "diagnostic",
                isControllable: HAHelpers.isControlDomain(domain),
                isActionable: HAHelpers.isActionDomain(domain),
                isInfo: HAHelpers.isInfoDomain(domain)
            };
            list.push(entry);
            byId[id] = entry;
        }

        list.sort(function(a, b) {
            var titleA = (a.name || a.id || "").toString().trim();
            var titleB = (b.name || b.id || "").toString().trim();
            var cmp = titleA.localeCompare(titleB, undefined, { numeric: true, sensitivity: "base" });
            if (cmp !== 0) return cmp;
            return (a.id || "").localeCompare(b.id || "");
        });

        manager.entityCatalog = list;
        manager._catalogById = byId;
        manager._catalogEntityCount = keys.length;
        manager._buildUserDevicesList();
        manager._buildGroups();
    }

    function _buildUserDevicesList() {
        var result = [];
        var catalog = manager.entityCatalog || [];

        for (var i = 0; i < catalog.length; i++) {
            var entry = catalog[i];
            if (manager._isEntityHiddenOrDisabled(entry)) continue;
            result.push(entry.id);
        }

        manager.userDevicesList = result;
    }

    function _buildGroups() {
        var catalog = manager.entityCatalog || [];
        var deviceMap = {};

        // Devices are built from every visible entity so the device page can
        // show channels/sensors. Areas, on the other hand, show one row per
        // device plus standalone entities, like Home Assistant's area page.
        for (var i = 0; i < catalog.length; i++) {
            var entry = catalog[i];
            if (manager._isEntityHiddenOrDisabled(entry)) continue;
            if (!entry.deviceId) continue;

            if (!deviceMap[entry.deviceId]) {
                deviceMap[entry.deviceId] = {
                    deviceId: entry.deviceId,
                    name: entry.deviceName || entry.name,
                    areaId: entry.areaId,
                    areaName: entry.areaName,
                    entityIds: []
                };
            }
            deviceMap[entry.deviceId].entityIds.push(entry.id);
        }

        var devices = [];
        var devKeys = Object.keys(deviceMap);
        for (var d = 0; d < devKeys.length; d++) {
            var group = deviceMap[devKeys[d]];
            group.primaryEntityId = manager.getPrimaryEntityForDevice(group.entityIds);
            if (group.primaryEntityId) devices.push(group);
        }
        devices.sort(function(a, b) {
            return (a.name || "").localeCompare(b.name || "", undefined, { numeric: true, sensitivity: "base" });
        });

        var areaMap = {};
        function ensureArea(areaId, areaName) {
            var key = areaId || "__unassigned__";
            if (!areaMap[key]) {
                var area = manager.getAreaRaw(areaId);
                var floorId = area ? (area.floor_id || area.floorId || "") : "";
                var floor = manager.getFloorRaw(floorId);
                areaMap[key] = {
                    areaId: areaId || "",
                    name: areaName || Loc.t("Unassigned"),
                    floorId: floorId,
                    floorName: floor ? (floor.name || "") : "",
                    entityIds: [],
                    deviceIds: []
                };
            }
            return areaMap[key];
        }

        for (var g = 0; g < devices.length; g++) {
            var devGroup = devices[g];
            var devArea = ensureArea(devGroup.areaId, devGroup.areaName);
            // Every controllable channel gets its own row: a two-gang switch
            // is two objects the user toggles independently. Devices that
            // only expose sensors fall back to their primary entity.
            var controlEnts = [];
            for (var c = 0; c < devGroup.entityIds.length; c++) {
                if (HAHelpers.isControlDomain(HAHelpers.getDomain(devGroup.entityIds[c]))) {
                    controlEnts.push(devGroup.entityIds[c]);
                }
            }
            if (controlEnts.length > 0) {
                for (var k = 0; k < controlEnts.length; k++) devArea.entityIds.push(controlEnts[k]);
            } else {
                devArea.entityIds.push(devGroup.primaryEntityId);
            }
            devArea.deviceIds.push(devGroup.deviceId);
        }

        for (var s = 0; s < catalog.length; s++) {
            var standalone = catalog[s];
            if (standalone.deviceId) continue;
            if (manager._isEntityHiddenOrDisabled(standalone)) continue;
            var standaloneArea = ensureArea(standalone.areaId, standalone.areaName);
            standaloneArea.entityIds.push(standalone.id);
        }

        var areas = [];
        var areaKeys = Object.keys(areaMap);
        for (var a = 0; a < areaKeys.length; a++) {
            var areaGroup = areaMap[areaKeys[a]];
            areaGroup.entityIds.sort(function(x, y) {
                var ex = manager.getCatalogEntry(x);
                var ey = manager.getCatalogEntry(y);
                return ((ex && ex.name) || x).localeCompare(((ey && ey.name) || y), undefined, { numeric: true, sensitivity: "base" });
            });
            areas.push(areaGroup);
        }
        areas.sort(function(a, b) {
            if (!a.areaId && b.areaId) return 1;
            if (a.areaId && !b.areaId) return -1;
            return (a.name || "").localeCompare(b.name || "", undefined, { numeric: true, sensitivity: "base" });
        });

        manager.deviceGroups = devices;
        manager.areaGroups = areas;
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
        var count = manager.entities ? Object.keys(manager.entities).length : 0;
        if (count !== manager._catalogEntityCount) {
            manager._buildEntityCatalog();
        } else {
            manager._buildUserDevicesList();
        }
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
                manager.connectionStatus = Loc.t("Error: Connection timed out for %1", manager.host);
                if (manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                    manager._scheduleReconnect();
                }
            }
        }
    }

    Timer {
        id: autoReconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!manager.isConnected && manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                manager._connectSocket();
            }
        }
    }

    function _scheduleReconnect() {
        // Exponential backoff: 2s, 4s, 8s ... capped at 60s. Reset on auth_ok.
        var delay = Math.min(60000, 2000 * Math.pow(2, manager._reconnectAttempts));
        manager._reconnectAttempts++;
        autoReconnectTimer.interval = delay;
        if (!autoReconnectTimer.running) {
            autoReconnectTimer.start();
        }
    }

    // Home Assistant pings the WebSocket roughly every 40s. If we have not
    // received anything for 90s the connection is half-open and must be reset.
    Timer {
        id: rxWatchdogTimer
        interval: 90000
        repeat: false
        onTriggered: {
            if (!manager.isConnected) return;
            if (manager._lastRxMs > 0 && (Date.now() - manager._lastRxMs) >= rxWatchdogTimer.interval) {
                console.warn("HA-hub: no data received for", rxWatchdogTimer.interval / 1000, "s. Resetting connection.");
                manager.isConnected = false;
                manager._failPendingHandlers("connection_lost");
                manager.state = "DISCONNECTED";
                manager.connectionStatus = Loc.t("Connection lost");
                manager._scheduleReconnect();
            } else {
                rxWatchdogTimer.restart();
            }
        }
    }

    function _failPendingHandlers(reason) {
        var ids = Object.keys(manager._customMsgHandlers);
        for (var i = 0; i < ids.length; i++) {
            var cb = manager._customMsgHandlers[ids[i]];
            delete manager._customMsgHandlers[ids[i]];
            if (cb) {
                try {
                    cb(null, false, reason || "disconnected");
                } catch (e) {
                    console.warn("HA-hub: pending handler threw:", e);
                }
            }
        }
    }

    Timer {
        id: registryRefreshTimer
        interval: 900
        repeat: false
        onTriggered: {
            manager._registryRefreshPending = false;
            if (manager.isConnected) manager._fetchRegistries();
        }
    }

    MDNSDiscovery {
        id: mdns
        onDiscoveryFinished: function(serverList) {
            connTimeoutTimer.stop();
            manager.discoveredServers = serverList;
            if (serverList.length > 0) {
                manager.connectionStatus = Loc.t("Found devices: %1", serverList.length);
            } else {
                manager.connectionStatus = Loc.t("No devices found in local network");
            }
        }
    }

    WebSocket {
        id: webSocket
        active: false

        onStatusChanged: function() {
            if (webSocket.status === WebSocket.Error) {
                connTimeoutTimer.stop();
                var err = webSocket.errorString || Loc.t("Unable to connect to server");
                if (manager.useSsl && (err.indexOf("wrong version number") !== -1 || err.indexOf("SSL routines") !== -1 || err.indexOf("handshake") !== -1)) {
                    manager.connectionStatus = Loc.t("SSL Error: HA server is running without SSL. Uncheck 'SSL (wss://)'");
                } else {
                    manager.connectionStatus = Loc.t("Error: %1", err);
                }
                manager.state = "ERROR";
                manager.isConnected = false;
                rxWatchdogTimer.stop();
                manager._failPendingHandlers("connection_error");
                if (manager.autoReconnectAllowed) manager._scheduleReconnect();
            } else if (webSocket.status === WebSocket.Closed) {
                connTimeoutTimer.stop();
                rxWatchdogTimer.stop();

                if (manager._isManualDisconnecting) {
                    manager._isManualDisconnecting = false;
                    manager._failPendingHandlers("disconnected");
                    return;
                }

                if (manager.state !== "ERROR") {
                    manager.state = "DISCONNECTED";
                    manager.connectionStatus = Loc.t("Disconnected");
                }
                manager.isConnected = false;
                manager._failPendingHandlers("disconnected");
                if (manager.autoReconnectAllowed && manager.accessToken.length > 0) {
                    manager._scheduleReconnect();
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
        if (!deviceId) return null;
        if (manager._deviceById && manager._deviceById[deviceId]) return manager._deviceById[deviceId];
        if (!devicesList) return null;
        for (var i = 0; i < devicesList.length; i++) {
            if (devicesList[i].id === deviceId) return devicesList[i];
        }
        return null;
    }

    function getAreaRaw(areaId) {
        if (!areaId) return null;
        return manager._areaById ? (manager._areaById[areaId] || null) : null;
    }

    function getFloorRaw(floorId) {
        if (!floorId) return null;
        return manager._floorById ? (manager._floorById[floorId] || null) : null;
    }

    function getEntityRegistry(entId) {
        return manager.entityRegistryMap ? (manager.entityRegistryMap[entId] || null) : null;
    }

    function getCatalogEntry(entId) {
        if (!entId) return null;
        return manager._catalogById ? (manager._catalogById[entId] || null) : null;
    }

    // ---- Static HTTP resources ------------------------------------------
    // Avatars (and camera snapshots) are served over plain HTTP, not through
    // the WebSocket. QML's Image cannot send an Authorization header, so the
    // token travels as a query parameter, which Home Assistant still accepts
    // for image resources.
    readonly property string httpBaseUrl: {
        var clean = String(host || "").replace(/^https?:\/\//i, "").replace(/^wss?:\/\//i, "").replace(/\/+$/, "");
        if (!clean) return "";
        return (useSsl ? "https://" : "http://") + clean + ":" + port;
    }

    function resourceUrl(pathOrUrl) {
        if (!pathOrUrl) return "";
        if (/^https?:\/\//i.test(pathOrUrl)) return pathOrUrl;
        var base = manager.httpBaseUrl;
        if (!base) return "";
        var url = base + (pathOrUrl.charAt(0) === "/" ? pathOrUrl : "/" + pathOrUrl);
        if (manager.accessToken && url.indexOf("auth_token=") === -1) {
            url += (url.indexOf("?") === -1 ? "?" : "&") + "auth_token=" + manager.accessToken;
        }
        return url;
    }

    // The person whose picture and name the header shows. Configured id wins,
    // otherwise the first person that actually has a picture.
    property string headerPersonEntityId: (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration)
        ? (Plasmoid.configuration.headerPersonEntityId || "")
        : ""

    readonly property string primaryPersonEntityId: {
        var rev = manager.entitiesRevision;
        if (manager.headerPersonEntityId && manager.entities[manager.headerPersonEntityId]) {
            return manager.headerPersonEntityId;
        }
        var keys = Object.keys(manager.entities || {});
        var fallback = "";
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf("person.") !== 0) continue;
            if (!fallback) fallback = keys[i];
            var ent = manager.entities[keys[i]];
            if (ent && ent.attributes && ent.attributes.entity_picture) return keys[i];
        }
        return fallback;
    }

    readonly property var personOptions: {
        var rev = manager.entitiesRevision;
        var keys = Object.keys(manager.entities || {});
        var result = [];
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf("person.") !== 0) continue;
            var ent = manager.entities[keys[i]];
            result.push({
                id: keys[i],
                name: (ent && ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name : keys[i]
            });
        }
        result.sort(function(a, b) { return a.name.localeCompare(b.name); });
        return result;
    }

    readonly property string primaryPersonName: {
        var id = manager.primaryPersonEntityId;
        if (!id) return "";
        var ent = manager.entities[id];
        return (ent && ent.attributes && ent.attributes.friendly_name) ? ent.attributes.friendly_name : "";
    }

    // Empty when the person has no picture in Home Assistant.
    readonly property string primaryPersonPictureUrl: {
        var id = manager.primaryPersonEntityId;
        if (!id) return "";
        var ent = manager.entities[id];
        var picture = (ent && ent.attributes) ? (ent.attributes.entity_picture || "") : "";
        return picture ? manager.resourceUrl(picture) : "";
    }

    function getEntityTitle(entId) {
        var entry = manager.getCatalogEntry(entId);
        if (entry) return entry.name;
        return HAHelpers.getEntityTitle(entId, manager.getEntity(entId), manager.getEntityRegistry(entId), manager);
    }

    function getAreaName(areaId) {
        var area = manager.getAreaRaw(areaId);
        return area ? (area.name || "") : "";
    }

    function _rebuildLookupMaps() {
        var devices = {};
        for (var d = 0; d < (manager.devicesList || []).length; d++) {
            var dev = manager.devicesList[d];
            if (dev && dev.id) devices[dev.id] = dev;
        }
        manager._deviceById = devices;

        var areas = {};
        for (var a = 0; a < (manager.areasList || []).length; a++) {
            var area = manager.areasList[a];
            var areaKey = area.area_id || area.id;
            if (areaKey) areas[areaKey] = area;
        }
        manager._areaById = areas;

        var floors = {};
        for (var f = 0; f < (manager.floorsList || []).length; f++) {
            var floor = manager.floorsList[f];
            var floorKey = floor.floor_id || floor.id;
            if (floorKey) floors[floorKey] = floor;
        }
        manager._floorById = floors;

        var labels = {};
        for (var l = 0; l < (manager.labelsList || []).length; l++) {
            var label = manager.labelsList[l];
            var labelKey = label.label_id || label.id;
            if (labelKey) labels[labelKey] = label;
        }
        manager._labelById = labels;
    }

    function _connectSocket() {
        if (!accessToken || accessToken.length === 0) {
            state = "ERROR";
            connectionStatus = Loc.t("Please enter Access Token");
            return;
        }

        _isManualDisconnecting = true;
        webSocket.active = false;

        connTimeoutTimer.restart();
        state = "AUTHENTICATING";
        connectionStatus = Loc.t("Connecting to %1:%2...", host, port);

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
        connectionStatus = Loc.t("Searching for servers in network...");
        mdns.startDiscovery(host);
    }

    function connectWithParams(newHost, newPort, newToken, ssl) {
        autoReconnectTimer.stop();
        connTimeoutTimer.stop();
        rxWatchdogTimer.stop();
        manager._reconnectAttempts = 0;
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
        rxWatchdogTimer.stop();
        manager._reconnectAttempts = 0;
        _isManualDisconnecting = true;
        webSocket.active = false;
        state = "DISCONNECTED";
        connectionStatus = Loc.t("Disconnected");
        isConnected = false;
        manager._failPendingHandlers("disconnected");
    }

    function _scheduleRegistryRefresh() {
        if (manager._registryRefreshPending) return;
        manager._registryRefreshPending = true;
        registryRefreshTimer.start();
    }

    function callService(domain, service, entityId, serviceData, callback, options) {
        if (!isConnected) {
            if (callback) callback(null, false, "not_connected");
            return 0;
        }
        var msgId = manager.getNextMessageId();
        var payload = HAClient.buildCallServicePayload(msgId, domain, service, serviceData || {}, entityId, options || null);
        if (callback) {
            manager._customMsgHandlers[msgId] = callback;
        }
        manager.safeSend(payload);
        return msgId;
    }

    function request(type, extra, callback) {
        if (!isConnected) {
            if (callback) callback(null, false, "not_connected");
            return 0;
        }
        var msgId = manager.getNextMessageId();
        var payload = { id: msgId, type: type };
        if (extra) {
            var keys = Object.keys(extra);
            for (var i = 0; i < keys.length; i++) payload[keys[i]] = extra[keys[i]];
        }
        if (callback) manager._customMsgHandlers[msgId] = callback;
        manager.safeSend(JSON.stringify(payload));
        return msgId;
    }

    function getDomainServices(domain) {
        if (!manager.servicesMap || !domain) return null;
        return manager.servicesMap[domain] || null;
    }

    function _handleIncomingMessage(rawMessage) {
        var parsed = HAClient.parseIncomingMessage(rawMessage);
        if (!parsed.success) return;
        var msg = parsed.data;

        manager._lastRxMs = Date.now();
        if (manager.isConnected) rxWatchdogTimer.restart();

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
            manager._reconnectAttempts = 0;
            isConnected = true;
            state = "CONNECTED";
            connectionStatus = Loc.t("Connected");
            manager._lastRxMs = Date.now();
            rxWatchdogTimer.start();
            manager.saveSharedCredentials();
            manager._subscribeToEvents();
            manager._fetchInitialStates();
            manager._fetchRegistries();
            return;
        }
        if (msg.type === "auth_invalid") {
            connTimeoutTimer.stop();
            autoReconnectTimer.stop();
            rxWatchdogTimer.stop();
            manager._failPendingHandlers("invalid_auth");
            state = "ERROR";
            connectionStatus = Loc.t("Invalid Access Token");
            manager.disconnectFromHA();
            return;
        }

        if (msg.id && _customMsgHandlers[msg.id]) {
            var callback = _customMsgHandlers[msg.id];
            delete _customMsgHandlers[msg.id];
            callback(msg.result, !!msg.success, msg.error || null);
            return;
        }

        if (msg.type === "event" && msg.event) {
            var eventType = msg.event.event_type || "";
            if (eventType === "state_changed") {
                var eventData = msg.event.data;
                if (eventData && eventData.entity_id) {
                    var entId = eventData.entity_id;
                    var catalogEntry = manager._catalogById ? manager._catalogById[entId] : null;
                    if (eventData.new_state) {
                        manager.entities[entId] = eventData.new_state;
                        manager._entitiesLowerMap[entId.toLowerCase()] = eventData.new_state;
                        // Friendly names can change through attributes while the
                        // entity count stays the same, so the count-based
                        // rebuild check in _notifyEntitiesChanged() would keep
                        // a stale title. Refresh the catalog explicitly.
                        if (catalogEntry) {
                            var reg = manager.entityRegistryMap ? manager.entityRegistryMap[entId] : null;
                            if (HAHelpers.getEntityTitle(entId, eventData.new_state, reg, manager) !== catalogEntry.name) {
                                manager._buildEntityCatalog();
                            }
                        }
                    } else {
                        // Entity was removed. Do not leave a stale state behind.
                        delete manager.entities[entId];
                        delete manager._entitiesLowerMap[entId.toLowerCase()];
                        if (catalogEntry) manager._buildEntityCatalog();
                    }
                    manager._notifyEntitiesChanged();
                }
            } else if (eventType.indexOf("_registry_updated") !== -1) {
                manager._scheduleRegistryRefresh();
            }
            return;
        }
    }

    // Sends a pre-built WS payload and routes the matching "result" message
    // to the callback through _customMsgHandlers. This keeps every request
    // self-contained: concurrent refreshes can never overwrite a shared
    // "last message id" variable and stale responses are simply ignored.
    function sendRequest(payloadText, callback) {
        if (!manager.isConnected) {
            if (callback) callback(null, false, "not_connected");
            return 0;
        }
        var parsed = HAClient.parseIncomingMessage(payloadText);
        if (!parsed.success || !parsed.data.id) return 0;
        var msgId = parsed.data.id;
        if (callback) manager._customMsgHandlers[msgId] = callback;
        manager.safeSend(payloadText);
        return msgId;
    }

    function _applyEntityRegistryResult(entReg) {
        var entToArea = {};
        var entToDev = {};
        var devToEnts = {};
        var regMap = {};

        if (!Array.isArray(entReg)) entReg = [];
        for (var e = 0; e < entReg.length; e++) {
            var item = entReg[e];
            if (!item.entity_id) continue;

            var isDisabled = (item.disabled_by !== null && item.disabled_by !== undefined);
            var isHidden = (item.hidden_by !== null && item.hidden_by !== undefined);

            regMap[item.entity_id] = {
                disabled: isDisabled,
                hidden: isHidden,
                category: item.entity_category || null,
                deviceId: item.device_id || "",
                areaId: item.area_id || "",
                name: item.name || "",
                originalName: item.original_name || "",
                icon: item.icon || "",
                labels: item.labels || [],
                platform: item.platform || "",
                configEntryId: item.config_entry_id || ""
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
        manager.entityRegistryMap = regMap;
        manager.entityToAreaMap = entToArea;
        manager.entityToDeviceMap = entToDev;
        manager.deviceToEntitiesMap = devToEnts;
        manager._buildFormattedDevices();
        manager._buildEntityCatalog();
        manager._notifyEntitiesChanged();
    }

    function _applyStatesResult(list) {
        var temp = {};
        var tempLower = {};
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
    }

    function _subscribeToEvents() {
        var eventTypes = [
            "state_changed",
            "entity_registry_updated",
            "device_registry_updated",
            "area_registry_updated",
            "floor_registry_updated",
            "label_registry_updated"
        ];
        for (var i = 0; i < eventTypes.length; i++) {
            manager.safeSend(HAClient.buildSubscribeEventsPayload(manager.getNextMessageId(), eventTypes[i]));
        }
    }

    function _fetchInitialStates() {
        manager.sendRequest(HAClient.buildGetConfigPayload(manager.getNextMessageId()), function(result, success) {
            if (success && result && result.location_name) {
                manager._updateCredentials(undefined, undefined, undefined, undefined, result.location_name);
                manager.saveSharedCredentials();
            }
        });

        manager.sendRequest(HAClient.buildGetStatesPayload(manager.getNextMessageId()), function(result, success) {
            if (!success || !result) return;
            manager._applyStatesResult(result);
        });
    }

    function _fetchRegistries() {
        manager.sendRequest(HAClient.buildGetAreasPayload(manager.getNextMessageId()), function(result, success) {
            if (!success) return;
            manager.areasList = result || [];
            manager._rebuildLookupMaps();
            if (manager.entities && Object.keys(manager.entities).length > 0) manager._buildEntityCatalog();
            manager._notifyEntitiesChanged();
        });

        manager.sendRequest(HAClient.buildGetFloorsPayload(manager.getNextMessageId()), function(result, success) {
            if (!success) return;
            manager.floorsList = result || [];
            manager._rebuildLookupMaps();
            if (manager.entities && Object.keys(manager.entities).length > 0) manager._buildEntityCatalog();
            manager._notifyEntitiesChanged();
        });

        manager.sendRequest(HAClient.buildGetLabelsPayload(manager.getNextMessageId()), function(result, success) {
            if (!success) return;
            manager.labelsList = result || [];
            manager._rebuildLookupMaps();
        });

        manager.sendRequest(HAClient.buildGetServicesPayload(manager.getNextMessageId()), function(result, success) {
            if (!success) return;
            manager.servicesMap = result || {};
        });

        // The entity registry needs the device->area map first, so it is
        // requested from inside the device registry callback.
        manager.sendRequest(HAClient.buildGetDevicesPayload(manager.getNextMessageId()), function(result, success) {
            if (!success) return;
            var devs = result || [];
            var devToArea = {};
            manager.devicesList = devs;
            for (var d = 0; d < devs.length; d++) {
                if (devs[d].id && devs[d].area_id) {
                    devToArea[devs[d].id] = devs[d].area_id;
                }
            }
            manager._tempDeviceToAreaMap = devToArea;
            manager._rebuildLookupMaps();
            manager._buildFormattedDevices();

            manager.sendRequest(HAClient.buildGetEntityRegistryPayload(manager.getNextMessageId()), function(regResult, regSuccess) {
                if (!regSuccess || !regResult) return;
                manager._applyEntityRegistryResult(regResult);
            });
        });
    }
}
