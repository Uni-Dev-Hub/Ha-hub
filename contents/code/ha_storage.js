.pragma library

function getSharedDb(localStorageModule) {
    try {
        return localStorageModule.openDatabaseSync("HAHubSharedAuthDB", "1.0", "HA-Hub Shared Credentials", 100000);
    } catch (e) {
        console.warn("HA-hub LocalStorage open error:", e);
        return null;
    }
}

function loadSharedCredentials(localStorageModule, fallbackHost, fallbackPort, fallbackServerName) {
    var db = getSharedDb(localStorageModule);
    if (!db) return null;

    var result = null;
    try {
        db.transaction(function(tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS auth (key TEXT PRIMARY KEY, value TEXT)');
            var res = tx.executeSql('SELECT key, value FROM auth');
            var data = {};
            for (var i = 0; i < res.rows.length; i++) {
                data[res.rows.item(i).key] = res.rows.item(i).value;
            }
            if (data["accessToken"] && data["accessToken"].length > 0) {
                result = {
                    host: data["host"] || fallbackHost || "homeassistant.local",
                    port: parseInt(data["port"]) || fallbackPort || 8123,
                    accessToken: data["accessToken"],
                    useSsl: data["useSsl"] === "true",
                    serverName: data["serverName"] || fallbackServerName || "Home Assistant"
                };
            }
        });
    } catch (e) {
        console.warn("HA-hub LocalStorage load error:", e);
    }
    return result;
}

function saveSharedCredentials(localStorageModule, host, port, accessToken, useSsl, serverName) {
    if (!accessToken || accessToken.length === 0) return false;
    var db = getSharedDb(localStorageModule);
    if (!db) return false;

    try {
        db.transaction(function(tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS auth (key TEXT PRIMARY KEY, value TEXT)');
            tx.executeSql('INSERT OR REPLACE INTO auth VALUES (?, ?)', ['accessToken', accessToken]);
            tx.executeSql('INSERT OR REPLACE INTO auth VALUES (?, ?)', ['host', host || ""]);
            tx.executeSql('INSERT OR REPLACE INTO auth VALUES (?, ?)', ['port', (port || 8123).toString()]);
            tx.executeSql('INSERT OR REPLACE INTO auth VALUES (?, ?)', ['useSsl', useSsl ? "true" : "false"]);
            tx.executeSql('INSERT OR REPLACE INTO auth VALUES (?, ?)', ['serverName', serverName || "Home Assistant"]);
        });
        return true;
    } catch (e) {
        console.warn("HA-hub LocalStorage save error:", e);
        return false;
    }
}
