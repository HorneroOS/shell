.pragma library

// Customisation overview (Control Center): which settings differ from the
// factory defaults, how to name them, where to edit them, and what "reset
// all" is allowed to touch. Pure functions, run under node in
// tests/test_customisation_overview.py; the pane supplies the current
// config (Config.serializeConfig()) and the factory file.

// Sections that are customisation (look, size, behaviour). Everything else
// (apps, paths, plugins, layouts, user lists) is the user's data and is never
// listed or reset here.
var SECTIONS = ["appearance", "border", "notifs", "osd", "session", "lock", "sidebar", "utilities", "launcher", "controlCenter", "bar", "background", "dashboard"];

// Keys inside an included section that are user data, not customisation.
var EXCLUDED = [
    "launcher.favouriteApps", "launcher.hiddenApps", "launcher.actions",
    "session.commands", "session.icons",
    "bar.bars", "bar.perScreen", "bar.excludedScreens",
    "controlCenter.appearanceOpenSections",
    "appearance.transparency.elements", "appearance.chromatic",
    "utilities.vpn", "launcher.useFuzzy"
];

// Path prefix -> [pane id, section id] (see PaneRegistry.qml).
var WHERE = [
    ["appearance.glow", "appearance", "look"],
    ["appearance.anim", "appearance", "look"],
    ["appearance.font", "appearance", "fonts"],
    ["appearance.transparency", "appearance", "transparency"],
    ["appearance", "appearance", "scales"],
    ["border", "appearance", "border"],
    ["background", "appearance", "background"],
    ["controlCenter", "appearance", "look"],
    ["launcher", "launcher", ""],
    ["notifs", "notifications", ""],
    ["sidebar", "notifications", ""],
    ["utilities", "notifications", ""],
    ["osd", "osd", ""],
    ["session", "session", ""],
    ["lock", "lockscreen", ""],
    ["bar", "taskbar", ""],
    ["dashboard", "dashboard", ""]
];

function _isPlain(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Flatten nested objects to {"a.b.c": leaf}. Arrays and empty objects are leaves.
function flatten(obj, prefix, out) {
    out = out || {};
    prefix = prefix || "";
    var keys = Object.keys(obj || {});
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var path = prefix ? prefix + "." + k : k;
        var v = obj[k];
        if (_isPlain(v) && Object.keys(v).length > 0)
            flatten(v, path, out);
        else
            out[path] = v;
    }
    return out;
}

function isCustomisation(path) {
    var top = path.split(".")[0];
    if (SECTIONS.indexOf(top) < 0)
        return false;
    for (var i = 0; i < EXCLUDED.length; i++)
        if (path === EXCLUDED[i] || path.indexOf(EXCLUDED[i] + ".") === 0)
            return false;
    return true;
}

function _same(a, b) {
    if (typeof a === "number" && typeof b === "number")
        return Math.abs(a - b) < 1e-9;
    return JSON.stringify(a) === JSON.stringify(b);
}

function _humanise(seg) {
    var s = seg.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
    return s.charAt(0).toUpperCase() + s.slice(1);
}

function labelFor(path) {
    return path.split(".").map(_humanise).join(" › ");
}

function whereFor(path) {
    for (var i = 0; i < WHERE.length; i++) {
        var w = WHERE[i];
        if (path === w[0] || path.indexOf(w[0] + ".") === 0)
            return { pane: w[1], section: w[2] };
    }
    return { pane: "appearance", section: "" };
}

// Settings whose current value differs from the factory value, sorted by path.
// A key missing from the factory file is ignored (nothing to reset to).
function changed(current, factory) {
    var cur = flatten(current), fac = flatten(factory);
    var out = [];
    Object.keys(fac).sort().forEach(function (path) {
        if (!isCustomisation(path) || !(path in cur))
            return;
        if (_same(cur[path], fac[path]))
            return;
        var w = whereFor(path);
        out.push({ path: path, label: labelFor(path), current: cur[path], factory: fac[path], pane: w.pane, section: w.section });
    });
    return out;
}

// Case-insensitive match of every query word against label + path.
function filter(items, query) {
    var words = String(query || "").toLowerCase().split(/\s+/).filter(function (w) { return w.length > 0; });
    if (words.length === 0)
        return items;
    return items.filter(function (it) {
        var hay = (it.label + " " + it.path).toLowerCase();
        return words.every(function (w) { return hay.indexOf(w) >= 0; });
    });
}

function display(v) {
    if (Array.isArray(v) || _isPlain(v))
        return JSON.stringify(v);
    if (typeof v === "number")
        return String(Math.round(v * 1000) / 1000);
    return String(v);
}

// ---- Look packs: share your customisation as JSON ----------------------
// A pack carries only the settings that differ from the defaults, keyed by
// dotted path. Import validates every entry against the factory file: the
// path must be a customisation path that exists there, the value must have
// the same type, and numbers are clamped to a sane range around the factory
// value so a hand-edited pack cannot make the shell unusable.
var PACK_SCHEMA = "hornero/look-pack@1";

function exportPack(current, factory, name) {
    var values = {};
    changed(current, factory).forEach(function (it) { values[it.path] = it.current; });
    return { schema: PACK_SCHEMA, name: name || "My look", values: values };
}

function _type(v) {
    return Array.isArray(v) ? "array" : v === null ? "null" : typeof v;
}

function validatePack(pack, factory, ranges) {
    ranges = ranges || {};
    var fac = flatten(factory);
    var accepted = [], rejected = [];
    if (!_isPlain(pack) || pack.schema !== PACK_SCHEMA || !_isPlain(pack.values))
        return { accepted: [], rejected: [{ path: "", reason: "not a Hornero look pack" }] };
    Object.keys(pack.values).sort().forEach(function (path) {
        var v = pack.values[path];
        if (!(path in fac) || !isCustomisation(path)) {
            rejected.push({ path: path, reason: "unknown setting" });
            return;
        }
        var f = fac[path];
        if (_type(v) !== _type(f)) {
            rejected.push({ path: path, reason: "wrong type" });
            return;
        }
        if (typeof v === "number") {
            if (!isFinite(v)) {
                rejected.push({ path: path, reason: "not a number" });
                return;
            }
            // Within 0..10x the factory value (or +-1000 for zero/negative
            // factories); the pane's own sliders enforce tighter ranges.
            var lo = f > 0 ? 0 : f - 1000, hi = f > 0 ? Math.max(f * 10, 10) : f + 1000;
            // The Control Center slider range (config/ranges.json) wins.
            if (ranges[path]) {
                lo = ranges[path].min;
                hi = ranges[path].max;
            }
            v = Math.max(lo, Math.min(hi, v));
        }
        accepted.push({ path: path, value: v, label: labelFor(path) });
    });
    return { accepted: accepted, rejected: rejected };
}
