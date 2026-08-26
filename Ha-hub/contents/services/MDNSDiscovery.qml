import QtQuick

Item {
    id: discovery

    property bool isSearching: false
    property int defaultPort: 8123

    signal discoveryFinished(var foundServers)

    property var _foundServers: []
    property int _pendingRequests: 0

    Timer {
        id: globalTimeoutTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (discovery.isSearching) {
                discovery.stopDiscovery();
                discovery.discoveryFinished(discovery._foundServers);
            }
        }
    }

    function startDiscovery(customHost) {
        stopDiscovery();

        isSearching = true;
        _foundServers = [];

        var candidates = [
            "homeassistant.local",
            "homeassistant",
            "localhost",
            "127.0.0.1"
        ];

        if (customHost && customHost.length > 0 && candidates.indexOf(customHost) === -1) {
            candidates.push(customHost);
        }

        _pendingRequests = candidates.length;
        globalTimeoutTimer.restart();

        for (var c = 0; c < candidates.length; c++) {
            _probeCandidate(candidates[c]);
        }
    }

    function stopDiscovery() {
        globalTimeoutTimer.stop();
        isSearching = false;
        _pendingRequests = 0;
    }

    function _probeCandidate(host) {
        var xhr = new XMLHttpRequest();
        var url = "http://" + host + ":" + defaultPort + "/manifest.json";
        var finished = false;

        function handleDone(success, serverName) {
            if (finished) return;
            finished = true;
            if (success && discovery.isSearching) {
                discovery._addFoundServer(host, serverName || "Home Assistant");
            }
            discovery._checkDone();
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var name = "Home Assistant";
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data && data.name) name = data.name;
                    } catch(e) {}
                    handleDone(true, name);
                } else if (xhr.status === 401 || xhr.status === 405) {
                    handleDone(true, "Home Assistant");
                } else {
                    handleDone(false, null);
                }
            }
        };

        xhr.ontimeout = function() { handleDone(false, null); };
        xhr.onerror = function() { handleDone(false, null); };

        xhr.open("GET", url, true);
        xhr.timeout = 1500;

        try {
            xhr.send();
        } catch (e) {
            handleDone(false, null);
        }
    }

    function _checkDone() {
        _pendingRequests--;
        if (_pendingRequests <= 0 && isSearching) {
            globalTimeoutTimer.stop();
            isSearching = false;
            discoveryFinished(_foundServers);
        }
    }

    function _addFoundServer(host, name) {
        var normalizedHost = host;
        if (host === "127.0.0.1" || host === "::1") {
            normalizedHost = "localhost";
        }

        var exists = false;
        for (var k = 0; k < _foundServers.length; k++) {
            if (_foundServers[k].host === normalizedHost) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            _foundServers.push({
                host: normalizedHost,
                port: defaultPort,
                name: (name && name !== "Home Assistant") ? name : "Home Assistant",
                url: "http://" + normalizedHost + ":" + defaultPort
            });
        }
    }
}
