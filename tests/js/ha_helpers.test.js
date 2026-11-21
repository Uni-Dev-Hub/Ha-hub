const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const { loadLibrary } = require("./load-library.js");
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

// Deliberately no channel disambiguation anymore: the user asked for exactly
// the friendly name Home Assistant shows, even when several channels of one
// device then carry the same title.
test("titles are pure friendly names, even for duplicated channel names", () => {
    const device = { name: "Corridor", name_by_user: null };
    const manager = { getDeviceRaw: () => device, entityToDeviceMap: {} };
    const channel = (obj, friendly) => ({ attributes: { friendly_name: friendly }, entity_id: obj });
    assert.equal(helpers.getEntityTitle("switch.a_light", channel("switch.a_light", "Коридор Свет"), null, manager), "Коридор Свет");
    assert.equal(helpers.getEntityTitle("switch.a_1", channel("switch.a_1", "Corridor"), null, manager), "Corridor");
    assert.equal(helpers.getEntityTitle("switch.a_2", channel("switch.a_2", "Corridor"), null, manager), "Corridor");
    assert.equal(helpers.getEntityTitle("switch.a_2", channel("switch.a_2", "Corridor"), null, manager),
                 helpers.getEntityTitle("switch.a_1", channel("switch.a_1", "Corridor"), null, manager),
                 "identical names stay identical");
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

test("tray icon choice resolves to exactly one of name or path", () => {
    const resolve = (mode, name, path, connected) =>
        helpers.resolveIconChoice(mode, name, path, "network-server-symbolic", "network-offline", connected);

    // The module is loaded through vm, so compare the plain shape.
    const shape = (r) => ({ name: r.name, path: r.path });
    assert.deepStrictEqual(shape(resolve("auto", "", "", true)), { name: "network-server-symbolic", path: "" });
    assert.deepStrictEqual(shape(resolve("auto", "", "", false)), { name: "network-offline", path: "" });
    assert.deepStrictEqual(shape(resolve("theme", "home", "", false)), { name: "home", path: "" });
    assert.deepStrictEqual(shape(resolve("custom", "", "/home/user/ha.png", true)), { name: "", path: "/home/user/ha.png" });
    // Half-configured values fall back to the automatic icon.
    assert.deepStrictEqual(shape(resolve("theme", "", "", true)), { name: "network-server-symbolic", path: "" });
    assert.deepStrictEqual(shape(resolve("custom", "", "", false)), { name: "network-offline", path: "" });
});

test("the tray icon gallery is a non-empty list of unique names", () => {
    const names = helpers.TRAY_ICON_CHOICES;
    assert.ok(names.length > 20, "the gallery should offer a real choice");
    assert.equal(new Set(names).size, names.length, "no duplicates in the gallery");
    for (const name of names) {
        assert.match(name, /^[a-z0-9-]+$/, name + " must be a freedesktop icon name");
    }
});


test("entity icons keep the choice Home Assistant made", () => {
    const shape = (r) => ({ kind: r.kind, name: r.name });

    // mdi: names are drawn from the bundled font, by their bare name.
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon("mdi:ceiling-light", "light")),
        { kind: "mdi", name: "ceiling-light" });
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon("  mdi:Thermometer  ", "sensor")),
        { kind: "mdi", name: "thermometer" });

    // An mdi: name the font does not carry, and icon sets we do not ship,
    // must fall back instead of drawing an empty box.
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon("mdi:not_a_real_icon", "light")),
        { kind: "theme", name: "brightness-high-symbolic" });
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon("phu:plug-zigbee", "switch")),
        { kind: "theme", name: helpers.getDomainIcon("switch") });

    // A plain theme name passes through, no icon takes the domain's one.
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon("network-wireless", "switch")),
        { kind: "theme", name: "network-wireless" });
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon("", "light")),
        { kind: "theme", name: "brightness-high-symbolic" });
    assert.deepStrictEqual(shape(helpers.resolveEntityIcon(null, undefined)),
        { kind: "theme", name: "preferences-system-symbolic" });
});

// Objects returned by the sandboxed library carry another realm's prototype, so
// they are compared as plain data.
const plain = value => JSON.parse(JSON.stringify(value));

// A name the user typed into the widget outranks whatever Home Assistant calls
// the entity - which is the whole point of being able to type one. It lives in
// one saved map, so it holds across groups and outlives the dashboard tile.
test("parseAliases survives whatever the configuration holds", () => {
    assert.deepStrictEqual(plain(helpers.parseAliases('{"light.hall":"Люстра"}')), { "light.hall": "Люстра" });
    assert.deepStrictEqual(plain(helpers.parseAliases("")), {});
    assert.deepStrictEqual(plain(helpers.parseAliases(null)), {});
    assert.deepStrictEqual(plain(helpers.parseAliases(undefined)), {});
    // Half-written, hand-edited, or the wrong shape: no names and no throw.
    assert.deepStrictEqual(plain(helpers.parseAliases('{"light.hall": ')), {});
    assert.deepStrictEqual(plain(helpers.parseAliases("not json at all")), {});
    assert.deepStrictEqual(plain(helpers.parseAliases('["light.hall"]')), {});
    // Already parsed (a QML variant coming back from the manager).
    assert.deepStrictEqual(plain(helpers.parseAliases({ "light.hall": "Люстра" })), { "light.hall": "Люстра" });
});

test("an entity name is stored, replaced and taken back", () => {
    let names = {};
    names = helpers.setAlias(names, "light.hall", "Люстра");
    assert.equal(helpers.aliasFor(names, "light.hall"), "Люстра");

    names = helpers.setAlias(names, "light.hall", "  Люстра над столом  ");
    assert.equal(helpers.aliasFor(names, "light.hall"), "Люстра над столом", "typed spaces are trimmed");

    const two = helpers.setAlias(names, "sensor.out", "За окном");
    assert.equal(Object.keys(two).length, 2, "a second name does not touch the first");
    assert.equal(Object.keys(names).length, 1, "and the map handed in is left alone");

    // An empty name is not a name: it takes the override back.
    const cleared = helpers.setAlias(names, "light.hall", "   ");
    assert.equal(helpers.aliasFor(cleared, "light.hall"), "");

    // The configuration keeps this as a string; junk values are dropped on the
    // way through rather than shown as a name.
    assert.deepStrictEqual(plain(helpers.setAlias('{"a":"A"}', "b", "B")), { a: "A", b: "B" });
    assert.deepStrictEqual(plain(helpers.setAlias({ a: 42, b: "", c: { "x": 1 } }, "d", "D")), { d: "D" });
    assert.equal(helpers.aliasFor({ a: 42 }, "a"), "", "a number is not a name");
    assert.equal(helpers.aliasFor({}, undefined), "");
});

test("the typed name wins over what Home Assistant says", () => {
    const ent = { attributes: { friendly_name: "Hall light" } };

    assert.equal(helpers.getEntityTitle("light.hall", ent, null, { entityAliases: '{"light.hall":"Люстра"}' }),
        "Люстра");
    // With no override, nothing about name resolution changes.
    assert.equal(helpers.getEntityTitle("light.hall", ent, null, { entityAliases: "{}" }), "Hall light");
    assert.equal(helpers.getEntityTitle("light.hall", ent, null, null), "Hall light");
    assert.equal(helpers.getEntityTitle("light.hall", ent, null, { entityAliases: "{ broken" }), "Hall light");

    // The manager owns the parsed map and may answer directly; an answer that
    // is not a string must not become the entity's name.
    assert.equal(helpers.getEntityTitle("light.hall", ent, null, { entityAliasFor: () => "Свет" }), "Свет");
    assert.equal(helpers.getEntityTitle("light.hall", ent, null, { entityAliasFor: () => undefined }),
        "Hall light");
    assert.equal(helpers.managerAlias("light.hall", { entityAliases: "{ broken" }), "");
});

// The editor shows what Home Assistant calls an entity underneath the name the
// user typed, so an override reads as one. That line must not answer with the
// override itself, which is what getEntityTitle() does.
test("what Home Assistant calls it, and what the user renamed it to, are different answers", () => {
    const names = helpers.setAlias("{}", "light.hall", "Люстра");
    const manager = {
        entityAliases: JSON.stringify(names),
        entityToDeviceMap: { "light.hall": "dev1", "switch.pump": "dev1" },
        getDeviceRaw: () => ({ name: "Hall lamp" })
    };
    const ent = { attributes: { friendly_name: "Hall light" } };

    assert.equal(helpers.getEntityTitle("light.hall", ent, null, manager), "Люстра");
    assert.equal(helpers.entityTitleFromAssistant("light.hall", ent, null, manager), "Hall light");

    // Without a friendly name the device's name is the assistant's answer.
    assert.equal(helpers.entityTitleFromAssistant("switch.pump", {}, null, manager), "Hall lamp");
    // And with neither, the id is.
    assert.equal(helpers.entityTitleFromAssistant("sensor.x", {}, null, {}), "sensor.x");
});

// The small line under an entity's name in the settings list. It is one line
// for every row, renamed or not: a row that grew a second line only when it was
// renamed stood taller than its neighbours and left their controls off-centre.
test("the line under an entity's name is one line, whatever it is called", () => {
    assert.equal(helpers.entityRowSubtitle("light.hall", "light.hall"), "light.hall");
    assert.equal(helpers.entityRowSubtitle("", "light.hall"), "light.hall");
    assert.equal(helpers.entityRowSubtitle(null, ""), "");
    assert.equal(helpers.entityRowSubtitle("Hall light", "light.hall"),
                 "Hall light  •  light.hall");
    // Home Assistant often builds the friendly name from the device and the
    // entity, so the line may hold both; it is still one line.
    const long = helpers.entityRowSubtitle("Свет в ванной Ванная", "light.svet_v_vannoi");
    assert.equal(long.split("\n").length, 1);
    assert.ok(long.endsWith("light.svet_v_vannoi"), long);
});
