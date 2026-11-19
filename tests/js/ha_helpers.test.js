const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");
const assert = require("node:assert/strict");

function loadLibrary(relativePath) {
    let source = fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
    source = source.replace(/^\.pragma library\s*/m, "");
    const context = { console };
    vm.createContext(context);
    // ESM imports as used inside the QML package:
    //   import * as T from "../l10n/translations.mjs";
    //   import { translate } from "../l10n/translations.mjs";
    const star = [...source.matchAll(/^import\s+\*\s+as\s+(\w+)\s+from\s+"([^"]+)";?\s*$/gm)];
    const named = [...source.matchAll(/^import\s+\{([^}]+)\}\s+from\s+"([^"]+)";?\s*$/gm)];
    source = source.replace(/^import\s+(?:\*\s+as\s+\w+|\{[^}]+\})\s+from\s+"[^"]+";?\s*$/gm, "");
    for (const [, alias, spec] of star) {
        context[alias] = loadLibrary(path.join(path.dirname(relativePath), spec));
    }
    for (const [, names, spec] of named) {
        const dep = loadLibrary(path.join(path.dirname(relativePath), spec));
        for (const name of names.split(",").map((s) => s.trim()).filter(Boolean)) {
            context[name] = dep[name];
        }
    }
    // Inline `export function/var` become plain declarations; the trailing
    // `export { ... };` block is dropped (declarations are already global here).
    source = source.replace(/^export\s+(?=(?:async\s+)?(?:function|var|let|const)\b)/gm, "");
    source = source.replace(/^export\s*\{[^}]*\};?\s*$/gm, "");
    vm.runInContext(source, context, { filename: relativePath });
    return context;
}

const helpers = loadLibrary("contents/code/ha_helpers.mjs");

test("multi-gang switch channels are selectable, not secondary", () => {
    assert.equal(helpers.isSelectableEntity("switch.tuya_switch_1"), true);
    assert.equal(helpers.isSelectableEntity("switch.tuya_switch_2"), true);
    assert.equal(helpers.isSecondaryEntity("switch.tuya_switch_1", null), false);
});

test("control entities are not hidden by name heuristics", () => {
    assert.equal(helpers.isSecondaryEntity("switch.power_switch", null), false);
    assert.equal(helpers.isSecondaryEntity("light.temperature_lamp", null), false);
});

test("registry category is authoritative for config/diagnostic entities", () => {
    assert.equal(helpers.isSecondaryEntity("switch.identify", { category: "diagnostic" }), true);
    assert.equal(helpers.isSecondaryEntity("sensor.battery", { category: "diagnostic" }), true);
    assert.equal(helpers.isSecondaryEntity("switch.identify", { category: null }), false);
});

test("telemetry sensors still use suffix heuristics", () => {
    assert.equal(helpers.isSecondaryEntity("sensor.living_room_battery", null), true);
    assert.equal(helpers.isSecondaryEntity("sensor.living_room_temperature", null), true);
    assert.equal(helpers.isSecondaryEntity("sensor.living_room_humidity", null), true);
});

test("entity title prefers the entity name over the device name", () => {
    const reg = { name: "Left gang", deviceId: "dev1" };
    const manager = {
        entityToDeviceMap: { "switch.left": "dev1" },
        getDeviceRaw: (id) => (id === "dev1" ? { id: "dev1", name: "Kitchen switch" } : null)
    };
    assert.equal(
        helpers.getEntityTitle("switch.left", { attributes: { friendly_name: "Left gang" } }, reg, manager),
        "Left gang"
    );
});

test("device fallback works when entity has no friendly name", () => {
    const manager = {
        entityToDeviceMap: { "switch.left": "dev1" },
        getDeviceRaw: (id) => (id === "dev1" ? { id: "dev1", name: "Kitchen switch" } : null)
    };
    assert.equal(helpers.getEntityTitle("switch.left", {}, null, manager), "Kitchen switch");
});

test("friendly name of the entity wins over the short registry name", () => {
    // Realistic HA pair: the registry keeps only the custom (short) name,
    // attributes.friendly_name carries the name Home Assistant displays.
    const reg = { name: "Свет", originalName: "light", deviceId: "dev1" };
    const ent = { attributes: { friendly_name: "Коридор Свет" } };
    assert.equal(helpers.getEntityTitle("switch.corridor_light", ent, reg, {}), "Коридор Свет");
    assert.equal(helpers.getEntityFriendlyName("switch.corridor_light", ent, reg), "Коридор Свет");
});

test("registry and original names are still used when the entity is unknown", () => {
    assert.equal(helpers.getEntityFriendlyName("switch.x", null, { name: "Коридор Свет" }), "Коридор Свет");
    assert.equal(helpers.getEntityFriendlyName("switch.x", {}, { name: "", originalName: "light" }), "light");
    assert.equal(helpers.getEntityFriendlyName("switch.x", null, null), "switch.x");
});

test("multi-channel rows keep distinct friendly names untouched", () => {
    const entries = [
        { id: "switch.a_light", deviceId: "d1", deviceName: "Corridor", name: "Коридор Свет" },
        { id: "switch.a_nightlight", deviceId: "d1", deviceName: "Corridor", name: "Коридор Ночник" }
    ];
    helpers.disambiguateCatalogTitles(entries);
    assert.equal(entries[0].name, "Коридор Свет");
    assert.equal(entries[1].name, "Коридор Ночник");
});

test("channels of the same device with the same name get a suffix", () => {
    const entries = [
        { id: "switch.corridor_switch_1", deviceId: "d1", deviceName: "Corridor", name: "Corridor" },
        { id: "switch.corridor_switch_2", deviceId: "d1", deviceName: "Corridor", name: "Corridor" }
    ];
    helpers.disambiguateCatalogTitles(entries);
    assert.equal(entries[0].name, "Corridor • Switch 1");
    assert.equal(entries[1].name, "Corridor • Switch 2");
});

test("CONTROL_DOMAINS stays in sync with isControlDomain", () => {
    assert.ok(Array.isArray(helpers.CONTROL_DOMAINS));
    for (const domain of helpers.CONTROL_DOMAINS) {
        assert.equal(helpers.isControlDomain(domain), true);
    }
    assert.equal(helpers.isControlDomain("weather"), false);
});

test("ignored and unknown domains are not selectable", () => {
    assert.equal(helpers.isSelectableEntity("zone.home"), false);
    assert.equal(helpers.isSelectableEntity("sun.sun"), false);
    assert.equal(helpers.isSelectableEntity("persistent_notification.x"), false);
    assert.equal(helpers.isSelectableEntity("nonsense.entity"), false);
    assert.equal(helpers.isSelectableEntity("scene.good_morning"), true);
    assert.equal(helpers.isSelectableEntity("number.target"), true);
});

test("binary sensor titles depend on device class", () => {
    assert.equal(helpers.getBinarySensorStateTitle("on", "door"), "Open");
    assert.equal(helpers.getBinarySensorStateTitle("off", "window"), "Closed");
    assert.equal(helpers.getBinarySensorStateTitle("on", "moisture"), "Wet");
    assert.equal(helpers.getBinarySensorStateTitle("off", "moisture"), "Dry");
    assert.equal(helpers.getBinarySensorStateTitle("on", "lock"), "Unlocked");
    assert.equal(helpers.getBinarySensorStateTitle("on", "battery"), "Low");
    assert.equal(helpers.getBinarySensorStateTitle("on", ""), "On");
});

test("status details format per domain", () => {
    assert.equal(helpers.getStatusDetailsText("switch.a", { state: "on" }), "On");
    assert.equal(helpers.getStatusDetailsText("switch.a", { state: "unavailable" }), "Unavailable");
    assert.equal(helpers.getStatusDetailsText("lock.a", { state: "locked" }), "Locked");
    assert.equal(
        helpers.getStatusDetailsText("cover.a", { state: "closed", attributes: { current_position: 40 } }),
        "40% • Closed"
    );
    assert.equal(
        helpers.getStatusDetailsText("sensor.a", { state: "21.5", attributes: { unit_of_measurement: "°C" } }),
        "21.5 °C"
    );
    assert.equal(helpers.getStatusDetailsText("vacuum.a", { state: "docked" }), "Docked");
});

test("relative and absolute time formatting", () => {
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    assert.equal(helpers.formatTimeInState(fiveMinAgo), "5m");
    assert.equal(helpers.formatTimeInState(new Date(Date.now() + 60000).toISOString()), "");
    assert.equal(helpers.formatTimeInState("garbage"), "");

    assert.match(helpers.formatLastChangedDate(fiveMinAgo), /^\d{2}:\d{2}, \d{2} [A-Z][a-z]{2}$/);
    assert.equal(helpers.formatLastChangedDate(null, "—"), "—");
});

test("header value line formats one entity, optionally with its name", () => {
    const manager = { getCatalogEntry: (id) => (id === "sensor.room_temp" ? { name: "Гостиная" } : null) };
    const ent = { state: "23.5", attributes: { unit_of_measurement: "°C" } };
    assert.equal(helpers.getEntityHeaderValue("sensor.room_temp", ent, manager, "en", false), "23.5 °C");
    assert.equal(helpers.getEntityHeaderValue("sensor.room_temp", ent, manager, "en", true), "Гостиная: 23.5 °C");
    // Unknown entity must not print anything; a missing catalog entry drops
    // the prefix instead of showing "undefined".
    assert.equal(helpers.getEntityHeaderValue("sensor.gone", null, manager, "en", true), "");
    assert.equal(helpers.getEntityHeaderValue("sensor.other", { state: "7", attributes: {} }, manager, "en", true), "7");
});

test("device display name prefers user name", () => {
    assert.equal(helpers.getDeviceDisplayName({ name_by_user: "My Lamp", name: "Hue" }, ""), "My Lamp");
    assert.equal(helpers.getDeviceDisplayName({ name: "Hue" }, "fallback"), "Hue");
    assert.equal(helpers.getDeviceDisplayName(null, "fallback"), "fallback");
});

test("humanizeEntityObjectName turns object ids into labels", () => {
    assert.equal(helpers.humanizeEntityObjectName("switch.gang_1"), "Gang 1");
    assert.equal(helpers.humanizeEntityObjectName("light.toilet_light"), "Toilet light");
    assert.equal(helpers.humanizeEntityObjectName("fan.x-2"), "X 2");
    assert.equal(helpers.humanizeEntityObjectName(""), "");
});

test("catalog titles of same-named device channels are disambiguated", () => {
    const entries = [
        { id: "light.corridor_light", deviceId: "dev1", name: "Corridor" },
        { id: "light.corridor_toilet", deviceId: "dev1", name: "Corridor" },
        { id: "switch.other", deviceId: "dev1", name: "Other" },
        { id: "sensor.battery", deviceId: "", name: "Corridor" }
    ];
    helpers.disambiguateCatalogTitles(entries);
    assert.equal(entries[0].name, "Corridor • Light");
    assert.equal(entries[1].name, "Corridor • Toilet");
    assert.equal(entries[2].name, "Other");
    assert.equal(entries[3].name, "Corridor");
});

test("disambiguation keeps existing suffixes intact", () => {
    const entries = [
        { id: "switch.gang_1", deviceId: "d", name: "Switch • Gang 1" },
        { id: "switch.gang_2", deviceId: "d", name: "Switch • Gang 2" }
    ];
    helpers.disambiguateCatalogTitles(entries);
    assert.equal(entries[0].name, "Switch • Gang 1");
    assert.equal(entries[1].name, "Switch • Gang 2");
});
