.pragma library

// Per-layout override map (R-069 customisation inventory, section 4 layers:
// factory < preset < layout override < mode override < user).
//
// A layout preset (`horneroctl shell preset apply`) rewrites the bars and
// sizes. This module is the pure part of "remember my tweaks for this
// layout": which config keys may be overridden, how a value is validated,
// and how a map { layoutId: { key: value } } is captured, sanitised and
// applied. services/Layouts.qml is the only QML consumer; nothing here
// touches Config or the system, so it runs under node in
// tests/test_layout_overrides.py.

// Every overridable key (dotted path from the Config root) and its
// validator. The ranges match docs/LAYOUTS.md "Every value is a control".
var KEYS = {
    "bar.sizes.innerWidth": { type: "int", min: 22, max: 56 },
    "bar.sizes.contentScale": { type: "number", min: 0.75, max: 1.5 },
    "bar.sizes.iconScale": { type: "number", min: 0.6, max: 1.5 },
    "bar.sizes.textScale": { type: "number", min: 0.75, max: 1.5 },
    "bar.sizes.textWeight": { type: "int", min: 300, max: 600 },
    "bar.sizes.itemSpacing": { type: "number", min: 0.5, max: 2 },
    "bar.sizes.densityScale": { type: "number", min: 0.75, max: 1.5 },
    "bar.sizes.autoDensity": { type: "bool" },
    "bar.typeface": { type: "enum", values: ["mono", "sans"] },
    "appearance.rounding.scale": { type: "number", min: 0.5, max: 2 },
    "appearance.spacing.scale": { type: "number", min: 0.75, max: 1.5 },
    "appearance.padding.scale": { type: "number", min: 0.75, max: 1.5 }
};

var KEY_IDS = Object.keys(KEYS);

// A layout id is a preset name: lowercase letters, digits, dashes.
function validId(id) {
    return typeof id === "string" && /^[a-z0-9][a-z0-9-]{0,63}$/.test(id);
}

// The valid value for `key`, or undefined (unknown key or bad value).
function coerce(key, value) {
    var spec = KEYS[key];
    if (!spec || value === null || value === undefined)
        return undefined;
    if (spec.type === "bool")
        return typeof value === "boolean" ? value : undefined;
    if (spec.type === "enum")
        return spec.values.indexOf(value) >= 0 ? value : undefined;
    if (typeof value !== "number" || !isFinite(value))
        return undefined;
    var n = Math.max(spec.min, Math.min(spec.max, value));
    return spec.type === "int" ? Math.round(n) : Math.round(n * 1000) / 1000;
}

// Keep only known ids, known keys and valid values. Never throws.
function sanitize(map) {
    var out = {};
    if (!map || typeof map !== "object")
        return out;
    Object.keys(map).forEach(function (id) {
        if (!validId(id) || !map[id] || typeof map[id] !== "object")
            return;
        var row = {};
        Object.keys(map[id]).forEach(function (key) {
            var v = coerce(key, map[id][key]);
            if (v !== undefined)
                row[key] = v;
        });
        if (Object.keys(row).length > 0)
            out[id] = row;
    });
    return out;
}

// Snapshot the live values (get(key) -> value) as the override row of `id`.
// Returns a new map; the input is never mutated.
function remember(map, id, get) {
    var out = sanitize(map);
    if (!validId(id))
        return out;
    var row = {};
    KEY_IDS.forEach(function (key) {
        var v = coerce(key, get(key));
        if (v !== undefined)
            row[key] = v;
    });
    out[id] = row;
    return out;
}

// Drop the row of `id` (back to the preset as shipped).
function forget(map, id) {
    var out = sanitize(map);
    delete out[id];
    return out;
}

// The row to apply for `id`: sanitised, empty when none.
function rowFor(map, id) {
    var clean = sanitize(map);
    return validId(id) && clean[id] ? clean[id] : {};
}

// Apply the row of `id` through set(key, value); returns the keys written.
function applyRow(map, id, set) {
    var row = rowFor(map, id);
    var keys = Object.keys(row);
    keys.forEach(function (key) {
        set(key, row[key]);
    });
    return keys;
}

// The keys of `id`'s row whose saved value differs from the live one.
function drift(map, id, get) {
    var row = rowFor(map, id);
    return Object.keys(row).filter(function (key) {
        return get(key) !== row[key];
    });
}
