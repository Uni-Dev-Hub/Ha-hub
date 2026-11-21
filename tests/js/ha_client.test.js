const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const { loadLibrary } = require("./load-library.js");
const client = loadLibrary("contents/code/ha_client.js");

test("call_service supports entity target", () => {
    const payload = JSON.parse(client.buildCallServicePayload(1, "light", "turn_on", { brightness: 10 }, "light.kitchen"));
    assert.equal(payload.type, "call_service");
    assert.deepEqual(payload.target, { entity_id: "light.kitchen" });
    assert.equal(payload.service_data.brightness, 10);
});

test("call_service supports area target and return_response", () => {
    const payload = JSON.parse(client.buildCallServicePayload(
        2,
        "light",
        "turn_on",
        {},
        null,
        { target: { area_id: "kitchen" }, returnResponse: true }
    ));
    assert.deepEqual(payload.target, { area_id: "kitchen" });
    assert.equal(payload.return_response, true);
});

test("registry and capability payload builders use the expected WS commands", () => {
    assert.equal(JSON.parse(client.buildGetFloorsPayload(1)).type, "config/floor_registry/list");
    assert.equal(JSON.parse(client.buildGetLabelsPayload(2)).type, "config/label_registry/list");
    assert.equal(JSON.parse(client.buildGetServicesPayload(3)).type, "get_services");
    assert.equal(JSON.parse(client.buildSearchRelatedPayload(4, "entity", "light.kitchen")).type, "search/related");
});

test("history and logbook payloads include entity ids", () => {
    const history = JSON.parse(client.buildHistoryPayload(5, ["sensor.temp"], "2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z"));
    assert.equal(history.type, "history/history_during_period");
    assert.deepEqual(history.entity_ids, ["sensor.temp"]);

    const logbook = JSON.parse(client.buildLogbookPayload(6, "2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z", "light.kitchen"));
    assert.deepEqual(logbook.entity_ids, ["light.kitchen"]);
});

test("auth and event subscription payloads", () => {
    assert.deepEqual(JSON.parse(client.buildAuthPayload("tok")), { type: "auth", access_token: "tok" });

    const sub = JSON.parse(client.buildSubscribeEventsPayload(7, "state_changed"));
    assert.equal(sub.id, 7);
    assert.equal(sub.type, "subscribe_events");
    assert.equal(sub.event_type, "state_changed");

    // default subscription is state_changed
    assert.equal(JSON.parse(client.buildSubscribeEventsPayload(8)).event_type, "state_changed");
});

test("incoming message parser reports malformed JSON", () => {
    assert.equal(client.parseIncomingMessage('{"ok":1}').success, true);
    assert.equal(client.parseIncomingMessage("not json").success, false);
});
