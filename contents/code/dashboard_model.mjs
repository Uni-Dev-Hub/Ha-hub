// Data model behind the Metro-style dashboard: tile groups, each with a
// colour and a list of tiles. The whole model lives in one JSON string in the
// plasmoid configuration (dashboardGroups), so every function here works on
// plain arrays and strings and can be unit tested without QML.

// Flat tile colours, taken from the classic Metro accent palette. They are
// shown as unnamed swatches, so no translations are needed and any of them
// can be paired with light or dark text (see readableTextColor).
var METRO_COLORS = [
    "#0078d7", // blue
    "#0099bc", // teal
    "#00b294", // emerald
    "#60a917", // green
    "#87798e", // old rose
    "#744da9", // violet
    "#b146c2", // purple
    "#e81123", // red
    "#c50f1f", // crimson
    "#fa903e", // tangerine
    "#f7630c", // orange
    "#ffb900", // amber
    "#ffd800", // yellow
    "#10893e", // dark green
    "#498205", // sea green
    "#6f6fed", // cool blue
    "#4f6a5d", // moss
    "#7a7574", // stone
    "#004e5c", // deep teal
    "#2d7d9a" // steel
];

var TILE_SIZES = ["small", "medium", "wide", "large"];
var TILE_CONTENTS = ["", "both", "title", "icon"];

function isValidHex(value) {
    return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value.trim());
}

function normalizeHex(value) {
    if (!isValidHex(value)) return "";
    return value.trim().toLowerCase();
}

function normalizeColor(value) {
    var hex = normalizeHex(value);
    return hex ? hex : null;
}

// Black or white, whichever stays legible on the given tile colour. Uses the
// WCAG relative luminance with a threshold slightly above 0.5 so mid-tones
// such as amber get dark text.
function readableTextColor(hex) {
    var color = normalizeHex(hex);
    if (!color) return "#ffffff";
    var r = parseInt(color.substr(1, 2), 16) / 255;
    var g = parseInt(color.substr(3, 2), 16) / 255;
    var b = parseInt(color.substr(5, 2), 16) / 255;
    var channel = function (v) {
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    };
    var luminance = 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    return luminance > 0.45 ? "#1a1a1a" : "#ffffff";
}

// Grid footprint of a tile in columns/rows of the small 1x1 unit.
function tileSpan(size, columns) {
    var cols = Math.max(1, columns || 4);
    if (size === "small") return { cols: 1, rows: 1 };
    if (size === "medium") return { cols: Math.min(2, cols), rows: 2 };
    if (size === "wide") return { cols: cols, rows: 2 };
    return { cols: Math.min(4, cols), rows: 4 }; // large
}

// Metro-style first-fit packing as plain rectangles, so the UI can place the
// tiles with explicit x/y/width/height instead of a layout manager: a layout
// that sizes its columns from the tiles' preferred widths feeds the tile width
// back into the unit width (the feedback loop that made the grid explode).
// Here the unit comes from the popup width alone and never travels back up.
// `tiles` entries need a `size`; returns { rects, rows, height } with rects
// aligned to the input order (one rect per tile).
function layoutTiles(tiles, columns, unit, spacing) {
    var cols = Math.max(1, Math.floor(columns) || 1);
    var step = unit + spacing;
    var list = tiles || [];
    var occupied = []; // [rowStart, rowEnd, colStart, colEnd] per placed tile
    var maxRow = 0;

    function fits(r, c, w, h) {
        if (c + w > cols) return false;
        for (var i = 0; i < occupied.length; i++) {
            var o = occupied[i];
            if (r < o[1] && o[0] < r + h && c < o[3] && o[2] < c + w) return false;
        }
        return true;
    }

    var rects = [];
    for (var t = 0; t < list.length; t++) {
        var span = tileSpan(list[t] && list[t].size, cols);
        var w = Math.min(span.cols, cols);
        var h = span.rows;
        var placed = false;
        for (var r = 0; !placed && r <= 4096; r++) {
            for (var c = 0; c <= cols - w; c++) {
                if (fits(r, c, w, h)) {
                    occupied.push([r, r + h, c, c + w]);
                    if (r + h > maxRow) maxRow = r + h;
                    rects.push({
                        x: c * step,
                        y: r * step,
                        w: w * unit + (w - 1) * spacing,
                        h: h * unit + (h - 1) * spacing
                    });
                    placed = true;
                    break;
                }
            }
        }
        // Pathological input guard: never drop a tile from the output.
        if (!placed) rects.push({ x: 0, y: 0, w: unit, h: unit });
    }
    return {
        rects: rects,
        rows: maxRow,
        height: maxRow > 0 ? maxRow * unit + (maxRow - 1) * spacing : 0
    };
}

function parseGroups(json) {
    var raw = (json || "").toString().trim();
    if (!raw) return [];
    try {
        var parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
        return [];
    }
}

function dumpGroups(groups) {
    return JSON.stringify(Array.isArray(groups) ? groups : []);
}

function generateId(prefix, taken) {
    var used = taken || {};
    var n = 1;
    while (used[prefix + n]) n++;
    return prefix + n;
}

function sanitizeTile(tile, takenEntities) {
    if (!tile || !tile.entityId) return null;
    var entityId = tile.entityId.toString();
    if (takenEntities[entityId]) return null;
    takenEntities[entityId] = true;
    var size = TILE_SIZES.indexOf(tile.size) !== -1 ? tile.size : "medium";
    var content = TILE_CONTENTS.indexOf(tile.content) !== -1 ? tile.content : "";
    return { entityId: entityId, size: size, content: content };
}

function sanitizeGroup(group, takenIds, takenEntities) {
    if (!group || typeof group !== "object") return null;
    var id = group.id ? group.id.toString() : "";
    if (!id || takenIds[id]) id = generateId("g", takenIds);
    takenIds[id] = true;
    var tiles = [];
    var source = Array.isArray(group.tiles) ? group.tiles : [];
    for (var i = 0; i < source.length; i++) {
        var tile = sanitizeTile(source[i], takenEntities);
        if (tile) tiles.push(tile);
    }
    return {
        id: id,
        name: group.name ? group.name.toString() : "",
        color: normalizeColor(group.color),
        tiles: tiles
    };
}

function sanitizeGroups(groups) {
    var takenIds = {};
    // Shared across all groups: one entity, one tile on the whole dashboard.
    var takenEntities = {};
    var result = [];
    var source = Array.isArray(groups) ? groups : [];
    for (var i = 0; i < source.length; i++) {
        var group = sanitizeGroup(source[i], takenIds, takenEntities);
        if (group) result.push(group);
    }
    return result;
}

// Legacy card list (dashboardCards) becomes one unnamed group without a fixed
// colour, so it keeps following the system accent. The old sizes 1x1/2x1/1x2/
// 2x2 map onto the closest Metro sizes.
function migrateLegacyCards(cardsJson) {
    var cards = parseGroups(cardsJson);
    var tiles = [];
    var takenEntities = {};
    for (var i = 0; i < cards.length; i++) {
        var card = cards[i];
        if (!card || !card.entityId) continue;
        var size = "medium";
        if (card.size === "1x1") size = "small";
        else if (card.size === "2x1") size = "wide";
        else if (card.size === "1x2") size = "medium";
        else if (card.size === "2x2") size = "large";
        var tile = sanitizeTile({ entityId: card.entityId, size: size }, takenEntities);
        if (tile) tiles.push(tile);
    }
    if (tiles.length === 0) return [];
    return sanitizeGroups([{ id: "g-legacy", name: "", color: null, tiles: tiles }]);
}

// The single entry point the UI uses: configured groups, or the migrated
// legacy cards when nothing was configured yet (v1.0 users keep a dashboard).
// A saved but empty list ("[]") means the user deleted everything and must
// not resurrect the legacy cards.
function normalizeDashboardModel(groupsJson, legacyCardsJson) {
    var raw = (groupsJson || "").toString().trim();
    if (raw.length > 0) return sanitizeGroups(parseGroups(raw));
    return migrateLegacyCards(legacyCardsJson);
}

function findGroup(groups, groupId) {
    for (var i = 0; i < groups.length; i++) {
        if (groups[i].id === groupId) return groups[i];
    }
    return null;
}

function groupIndexOf(groups, groupId) {
    for (var i = 0; i < groups.length; i++) {
        if (groups[i].id === groupId) return i;
    }
    return -1;
}

function allTileEntityIds(groups) {
    var result = {};
    var list = [];
    var source = Array.isArray(groups) ? groups : [];
    for (var i = 0; i < source.length; i++) {
        var tiles = source[i] && Array.isArray(source[i].tiles) ? source[i].tiles : [];
        for (var t = 0; t < tiles.length; t++) {
            var id = tiles[t] && tiles[t].entityId;
            if (id && !result[id]) {
                result[id] = true;
                list.push(id);
            }
        }
    }
    return list;
}

function countTiles(groups) {
    var source = Array.isArray(groups) ? groups : [];
    var n = 0;
    for (var i = 0; i < source.length; i++) {
        if (source[i] && Array.isArray(source[i].tiles)) n += source[i].tiles.length;
    }
    return n;
}

// Every mutation returns a deep copy; the stored JSON is only replaced once
// the caller stores the result, so a failed edit cannot half-update the list.
function cloneGroups(groups) {
    return JSON.parse(JSON.stringify(Array.isArray(groups) ? groups : []));
}

function addGroup(groups, name, color) {
    var next = cloneGroups(groups);
    var taken = {};
    for (var i = 0; i < next.length; i++) taken[next[i].id] = true;
    next.push({
        id: generateId("g", taken),
        name: name ? name.toString() : "",
        color: normalizeColor(color),
        tiles: []
    });
    return next;
}

function removeGroup(groups, groupId) {
    var next = cloneGroups(groups);
    var index = groupIndexOf(next, groupId);
    if (index === -1) return cloneGroups(groups);
    next.splice(index, 1);
    return next;
}

function renameGroup(groups, groupId, name) {
    var next = cloneGroups(groups);
    var group = findGroup(next, groupId);
    if (!group) return cloneGroups(groups);
    group.name = name ? name.toString() : "";
    return next;
}

function setGroupColor(groups, groupId, color) {
    var next = cloneGroups(groups);
    var group = findGroup(next, groupId);
    if (!group) return cloneGroups(groups);
    group.color = normalizeColor(color);
    return next;
}

function moveGroup(groups, groupId, delta) {
    var next = cloneGroups(groups);
    var index = groupIndexOf(next, groupId);
    var target = index + (delta || 0);
    if (index === -1 || target < 0 || target >= next.length) return cloneGroups(groups);
    var item = next.splice(index, 1)[0];
    next.splice(target, 0, item);
    return next;
}

function addTile(groups, groupId, entityId, size) {
    if (!entityId) return cloneGroups(groups);
    if (allTileEntityIds(groups).indexOf(entityId) !== -1) return cloneGroups(groups);
    var next = cloneGroups(groups);
    var group = findGroup(next, groupId);
    if (!group) return cloneGroups(groups);
    group.tiles.push({
        entityId: entityId,
        size: TILE_SIZES.indexOf(size) !== -1 ? size : "medium",
        content: ""
    });
    return next;
}

function removeTile(groups, groupId, entityId) {
    var next = cloneGroups(groups);
    var group = findGroup(next, groupId);
    if (!group) return cloneGroups(groups);
    var kept = [];
    for (var i = 0; i < group.tiles.length; i++) {
        if (group.tiles[i].entityId !== entityId) kept.push(group.tiles[i]);
    }
    if (kept.length === group.tiles.length) return cloneGroups(groups);
    group.tiles = kept;
    return next;
}

// Moves a tile to the end of another group. The destination must exist; on a
// name collision inside it the whole edit is dropped.
function moveTile(groups, entityId, toGroupId) {
    var next = cloneGroups(groups);
    var from = null;
    var tile = null;
    for (var g = 0; g < next.length; g++) {
        var tiles = next[g].tiles;
        for (var t = 0; t < tiles.length; t++) {
            if (tiles[t].entityId === entityId) {
                from = next[g];
                tile = tiles[t];
                tiles.splice(t, 1);
                break;
            }
        }
        if (tile) break;
    }
    if (!tile) return cloneGroups(groups);
    var target = findGroup(next, toGroupId);
    if (!target) {
        // Destination vanished: put the tile back where it came from.
        for (var r = 0; r < next.length; r++) {
            if (next[r].id === from.id) { next[r].tiles.push(tile); break; }
        }
        return next;
    }
    var collision = false;
    for (var k = 0; k < target.tiles.length; k++) {
        if (target.tiles[k].entityId === entityId) collision = true;
    }
    if (collision) return cloneGroups(groups);
    target.tiles.push(tile);
    return next;
}

function groupOf(groups, entityId) {
    var source = Array.isArray(groups) ? groups : [];
    for (var i = 0; i < source.length; i++) {
        var tiles = source[i].tiles || [];
        for (var t = 0; t < tiles.length; t++) {
            if (tiles[t].entityId === entityId) return source[i].id;
        }
    }
    return "";
}

function setTileSize(groups, groupId, entityId, size) {
    var next = cloneGroups(groups);
    var group = findGroup(next, groupId);
    if (!group) return cloneGroups(groups);
    for (var i = 0; i < group.tiles.length; i++) {
        if (group.tiles[i].entityId === entityId) {
            group.tiles[i].size = TILE_SIZES.indexOf(size) !== -1 ? size : "medium";
            return next;
        }
    }
    return cloneGroups(groups);
}

function setTileContent(groups, groupId, entityId, content) {
    var next = cloneGroups(groups);
    var group = findGroup(next, groupId);
    if (!group) return cloneGroups(groups);
    for (var i = 0; i < group.tiles.length; i++) {
        if (group.tiles[i].entityId === entityId) {
            group.tiles[i].content = TILE_CONTENTS.indexOf(content) !== -1 ? content : "";
            return next;
        }
    }
    return cloneGroups(groups);
}

export {
    METRO_COLORS,
    TILE_SIZES,
    TILE_CONTENTS,
    isValidHex,
    normalizeHex,
    normalizeColor,
    readableTextColor,
    tileSpan,
    layoutTiles,
    parseGroups,
    dumpGroups,
    generateId,
    sanitizeGroups,
    migrateLegacyCards,
    normalizeDashboardModel,
    findGroup,
    groupIndexOf,
    allTileEntityIds,
    countTiles,
    groupOf,
    addGroup,
    removeGroup,
    renameGroup,
    setGroupColor,
    moveGroup,
    addTile,
    removeTile,
    moveTile,
    setTileSize,
    setTileContent
};
