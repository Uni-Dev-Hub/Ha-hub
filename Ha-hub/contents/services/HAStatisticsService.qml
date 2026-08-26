import QtQuick
import "../code/ha_client.js" as HAClient
import "../code/ha_statistics.js" as HAStats

Item {
    id: statsService

    property var haManager: null
    property bool isLoading: false
    property string activeEntityId: ""
    property string unit: ""
    property string deviceClass: ""

    property string currentValueStr: "0.00"
    property string todayValueStr: "0.00"
    property string weekValueStr: "0.00"
    property string monthValueStr: "0.00"
    property string totalValueStr: "0.00"

    property string todayMinStr: "—"
    property string todayMaxStr: "—"
    property string todayAvgStr: "—"

    property var last7DaysBreakdown: []
    property real max7DaysValue: 1.0

    property var binaryEventsList: []
    property int todayTriggersCount: 0
    property int past24hTriggersCount: 0

    property int _lastMsgId: 0
    property var _cache: ({})

    readonly property bool isEnergyOrTotal: {
        var u = (unit || "").toLowerCase();
        var dc = (deviceClass || "").toLowerCase();
        var id = (activeEntityId || "").toLowerCase();
        return u === "kwh" || u === "wh" || u === "квт⋅год" || u === "квтг" || u === "m³" || u === "l" ||
               dc === "energy" || id.indexOf("energy") !== -1 || id.indexOf("енерг") !== -1 || id.indexOf("споживан") !== -1;
    }

    function fetchBinarySensorHistory(entityId) {
        if (!haManager || !haManager.isConnected || !entityId) return;

        activeEntityId = entityId;
        isLoading = true;

        var now = new Date();
        var startISO = new Date(now.getTime() - 48 * 3600 * 1000).toISOString();

        _lastMsgId = haManager ? haManager.getNextMessageId() : HAClient.getNextId();

        var payload = JSON.stringify({
            id: _lastMsgId,
            type: "history/history_during_period",
            start_time: startISO,
            end_time: now.toISOString(),
            entity_ids: [entityId],
            significant_changes_only: true,
            minimal_response: true,
            no_attributes: true
        });

        haManager.registerStatsHandler(_lastMsgId, function(result) {
            statsService.isLoading = false;
            var records = (result && result[entityId] && Array.isArray(result[entityId])) ? result[entityId] : [];
            var processed = HAStats.processBinaryHistory(records);
            statsService.todayTriggersCount = processed.todayCount;
            statsService.past24hTriggersCount = processed.past24hCount;
            statsService.binaryEventsList = processed.events;
        });

        haManager.safeSend(payload);
    }

    function fetchDeviceStatistics(statisticId) {
        if (!haManager || !haManager.isConnected || !statisticId) return;

        activeEntityId = statisticId;

        var ent = haManager.getEntity(statisticId);
        if (ent && ent.attributes) {
            unit = ent.attributes.unit_of_measurement || (isEnergyOrTotal ? "kWh" : "");
            deviceClass = ent.attributes.device_class || "";
        }

        var cur = (ent && ent.state !== undefined && !isNaN(ent.state)) ? parseFloat(ent.state) : 0;
        currentValueStr = cur.toFixed(1) + (unit ? " " + unit : "");
        totalValueStr = cur.toFixed(2) + (unit ? " " + unit : "");

        var cacheKey = statisticId;
        var nowTs = Date.now();
        if (_cache[cacheKey] && (nowTs - _cache[cacheKey].ts < 5000)) {
            statsService._applyData(_cache[cacheKey].data);
            return;
        }

        isLoading = true;
        var now = new Date();
        var startFetch = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
        var startISO = new Date(startFetch.getTime() - 48 * 3600 * 1000).toISOString();

        _lastMsgId = haManager ? haManager.getNextMessageId() : HAClient.getNextId();

        var ltsPayload = JSON.stringify({
            id: _lastMsgId,
            type: "recorder/statistics_during_period",
            start_time: startISO,
            end_time: now.toISOString(),
            statistic_ids: [statisticId],
            period: "hour"
        });

        haManager.registerStatsHandler(_lastMsgId, function(result) {
            statsService.isLoading = false;
            var records = (result && result[statisticId] && Array.isArray(result[statisticId])) ? result[statisticId] : [];
            var entCur = haManager.getEntity(statisticId);
            var curVal = (entCur && entCur.state && !isNaN(entCur.state)) ? parseFloat(entCur.state) : 0;

            var data;
            if (statsService.isEnergyOrTotal) {
                data = HAStats.processEnergyLTS(records, curVal, statsService.unit);
            } else {
                data = HAStats.processClimateLTS(records, curVal, statsService.unit, statsService.deviceClass);
            }

            if (cacheKey) _cache[cacheKey] = { ts: Date.now(), data: data };
            statsService._applyData(data);
        });

        haManager.safeSend(ltsPayload);
    }

    function _applyData(data) {
        currentValueStr = data.currentValueStr;
        totalValueStr = data.totalValueStr;
        todayValueStr = data.todayValueStr;
        weekValueStr = data.weekValueStr;
        monthValueStr = data.monthValueStr;
        todayMinStr = data.todayMinStr || "—";
        todayMaxStr = data.todayMaxStr || "—";
        todayAvgStr = data.todayAvgStr || "—";
        last7DaysBreakdown = data.last7DaysBreakdown || [];
        max7DaysValue = data.max7DaysValue || 1.0;
    }
}
