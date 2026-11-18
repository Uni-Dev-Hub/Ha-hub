import QtQuick
import "../code/ha_client.js" as HAClient

Item {
    id: historyService

    property var haManager: null
    property string activeEntityId: ""
    property bool isLoading: false
    property var records: []
    property var events: []

    property int _lastMsgId: 0

    function formatEventTime(timestamp) {
        if (!timestamp) return "";
        var d = new Date(timestamp);
        if (isNaN(d.getTime())) return "";
        var day = String(d.getDate()).padStart(2, "0");
        var month = String(d.getMonth() + 1).padStart(2, "0");
        var hours = String(d.getHours()).padStart(2, "0");
        var mins = String(d.getMinutes()).padStart(2, "0");
        return day + "." + month + " " + hours + ":" + mins;
    }

    function processRecords(entityId) {
        var result = [];
        if (!records || !Array.isArray(records)) {
            events = [];
            return;
        }

        for (var i = 0; i < records.length; i++) {
            var rec = records[i];
            if (!rec) continue;

            var state = rec.state || rec.s || "";
            var tsRaw = rec.last_changed || rec.lu || rec.last_updated || rec.t || rec.time;
            var ts = tsRaw ? new Date(tsRaw).getTime() : 0;
            if (state === "" || !ts) continue;

            result.push({
                state: state,
                timestamp: ts,
                timeStr: formatEventTime(tsRaw)
            });
        }

        result.sort(function(a, b) { return b.timestamp - a.timestamp; });
        events = result.slice(0, 12);
    }

    function fetchHistory(entityId) {
        if (!haManager || !haManager.isConnected || !entityId) return;

        activeEntityId = entityId;
        isLoading = true;

        var now = new Date();
        var start = new Date(now.getTime() - 72 * 3600 * 1000);

        _lastMsgId = haManager ? haManager.getNextMessageId() : HAClient.getNextId();

        var payload = JSON.stringify({
            id: _lastMsgId,
            type: "history/history_during_period",
            start_time: start.toISOString(),
            end_time: now.toISOString(),
            entity_ids: [entityId],
            minimal_response: true,
            no_attributes: true
        });

        haManager.registerStatsHandler(_lastMsgId, function(result) {
            historyService.isLoading = false;
            historyService.records = (result && result[entityId] && Array.isArray(result[entityId])) ? result[entityId] : [];
            historyService.processRecords(entityId);
        });

        haManager.safeSend(payload);
    }
}
