function processBinaryHistory(records) {
    if (!records || !Array.isArray(records)) return { todayCount: 0, past24hCount: 0, events: [] };
    var now = Date.now();
    var past24hTs = now - 24 * 3600 * 1000;
    var startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    var todayTs = startOfToday.getTime();

    var todayCount = 0;
    var past24hCount = 0;
    var events = [];

    for (var i = 0; i < records.length; i++) {
        var rec = records[i];
        if (!rec) continue;
        var st = rec.state || (rec.s !== undefined ? rec.s : "");
        var lu = rec.last_changed || rec.lu || rec.last_updated || rec.t;
        var ts = lu ? new Date(lu).getTime() : 0;
        if (st === "on") {
            if (ts >= todayTs) todayCount++;
            if (ts >= past24hTs) past24hCount++;
        }
    }

    return {
        todayCount: todayCount,
        past24hCount: past24hCount,
        events: events
    };
}

function processClimateLTS(records, curVal, unit, deviceClass) {
    var u = unit ? " " + unit : "";
    if (!records || !Array.isArray(records) || records.length === 0) {
        var curStr = curVal !== undefined ? curVal.toFixed(1) + u : "—";
        return {
            currentValueStr: curStr,
            totalValueStr: curStr,
            todayMinStr: curStr,
            todayMaxStr: curStr,
            todayAvgStr: curStr,
            last7DaysBreakdown: [],
            max7DaysValue: 1.0
        };
    }

    var minVal = Infinity;
    var maxVal = -Infinity;
    var sumVal = 0;
    var count = 0;

    for (var i = 0; i < records.length; i++) {
        var r = records[i];
        var mean = (r.mean !== undefined && r.mean !== null) ? r.mean : (r.state !== undefined ? parseFloat(r.state) : NaN);
        var min = (r.min !== undefined && r.min !== null) ? r.min : mean;
        var max = (r.max !== undefined && r.max !== null) ? r.max : mean;

        if (!isNaN(min) && min < minVal) minVal = min;
        if (!isNaN(max) && max > maxVal) maxVal = max;
        if (!isNaN(mean)) {
            sumVal += mean;
            count++;
        }
    }

    var avgVal = count > 0 ? (sumVal / count) : curVal;
    var cur = curVal !== undefined ? curVal.toFixed(1) + u : "—";

    return {
        currentValueStr: cur,
        totalValueStr: cur,
        todayMinStr: minVal !== Infinity ? minVal.toFixed(1) + u : "—",
        todayMaxStr: maxVal !== -Infinity ? maxVal.toFixed(1) + u : "—",
        todayAvgStr: !isNaN(avgVal) ? avgVal.toFixed(1) + u : "—",
        last7DaysBreakdown: [],
        max7DaysValue: 1.0
    };
}

function processEnergyLTS(records, curVal, unit) {
    var u = unit ? " " + unit : " kWh";
    var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    var days = [];
    var maxVal = 1.0;

    var today = new Date();
    for (var d = 6; d >= 0; d--) {
        var date = new Date(today.getTime() - d * 24 * 3600 * 1000);
        var dayName = dayNames[date.getDay()];
        var dateStr = String(date.getDate()).padStart(2, "0") + "." + String(date.getMonth() + 1).padStart(2, "0");
        days.push({
            dayName: dayName,
            dateStr: dateStr,
            val: 0,
            valStr: "0.00",
            isToday: (d === 0)
        });
    }

    return {
        currentValueStr: (curVal ? curVal.toFixed(1) : "0.0") + u,
        totalValueStr: (curVal ? curVal.toFixed(2) : "0.00") + u,
        todayValueStr: "0.00" + u,
        weekValueStr: "0.00" + u,
        monthValueStr: "0.00" + u,
        last7DaysBreakdown: days,
        max7DaysValue: maxVal
    };
}
