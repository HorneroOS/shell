.pragma library

// Keybinding model (keybinding overlay + Control Center > Keybinds).
// Pure functions, executed under node by tests/test_keybinds_overlay.py;
// services/Keybinds.qml binds them to `horneroctl hardware keyboard
// rebind list|set|reset|undo` and to the compositor.
//
// Entries come from `rebind list --json` (data.entries): every active
// bind, live from Hyprland, with the config's category and action.

// Category presentation: Hornero Glyph, Spanish label (search matches
// both languages) and order. Unknown categories fall back to "keyboard".
var CATEGORIES = {
    "Essential Applications": { glyph: "apps", es: "Aplicaciones esenciales", order: 0 },
    "Window Management": { glyph: "app-window", es: "Ventanas", order: 1 },
    "Focus Movement (Vim-like)": { glyph: "current-location", es: "Mover el foco", order: 2 },
    "Window Movement": { glyph: "arrows-move", es: "Mover ventanas", order: 3 },
    "Window Resizing": { glyph: "resize", es: "Redimensionar ventanas", order: 4 },
    "Scrolling Layout Navigation (Niri-like)": { glyph: "layout-columns", es: "Diseño con desplazamiento", order: 5 },
    "Workspace Management": { glyph: "layout-grid", es: "Espacios de trabajo", order: 6 },
    "Group Management": { glyph: "folders", es: "Grupos de ventanas", order: 7 },
    "Media Keys": { glyph: "music", es: "Teclas multimedia", order: 8 },
    "Screenshots": { glyph: "screenshot", es: "Capturas de pantalla", order: 9 },
    "System Control": { glyph: "settings", es: "Control del sistema", order: 10 },
    "Mouse Bindings": { glyph: "mouse", es: "Atajos con el mouse", order: 11 },
    "Personal": { glyph: "star", es: "Personales", order: 12 },
    "Other": { glyph: "puzzle", es: "Otros (plugins y sesión)", order: 13 },
    "General": { glyph: "keyboard", es: "General", order: 14 }
};

// Internal submaps (the rebind capture submap) never show up.
var HIDDEN_SUBMAP_PREFIX = "hornero_";

var DEFAULTS = {
    runOnEnter: true,
    closeAfterRun: true,
    showSubmaps: true,
    showMouse: true,
    compact: false
};

// SUPER-hold key badges (#701): holdMs bounds mirror
// config/ranges.json (keybinds.superHold.holdMs).
var BADGE_DEFAULTS = {
    enabled: true,
    holdMs: 600
};
var BADGE_HOLD_MIN = 200;
var BADGE_HOLD_MAX = 3000;
// Safety net: badges never outlive this even if a release is missed
// (for example a combo that no interrupt bind saw).
var BADGE_MAX_SHOWN_MS = 10000;

// Detection binds the config registers for the badges (non-consuming
// `global` binds in keybindings-overlay.lua). They are shell plumbing,
// never user binds, so the overlay list hides them wherever the
// shortcut name shows up (action, dispatcher or label).
var BADGE_GLOBALS = ["hornero:superHoldArm", "hornero:superHoldRelease", "hornero:superHoldInterrupt"];

function isBadgeGlobal(entry) {
    var hay = [entry.action, entry.dispatcher, entry.label].join(" ");
    for (var i = 0; i < BADGE_GLOBALS.length; i++) {
        if (hay.indexOf(BADGE_GLOBALS[i]) >= 0)
            return true;
    }
    return false;
}

function badgeSettings(raw) {
    var hold = raw ? raw.holdMs : undefined;
    return {
        enabled: raw && typeof raw.enabled === "boolean" ? raw.enabled : BADGE_DEFAULTS.enabled,
        holdMs: typeof hold === "number" && isFinite(hold) ? Math.max(BADGE_HOLD_MIN, Math.min(BADGE_HOLD_MAX, Math.round(hold))) : BADGE_DEFAULTS.holdMs
    };
}

var MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"];
var MOD_ALIASES = {
    SUPER: "SUPER", WIN: "SUPER", META: "SUPER", LOGO: "SUPER", MOD4: "SUPER", MAINMOD: "SUPER",
    ALT: "ALT", MOD1: "ALT", CTRL: "CTRL", CONTROL: "CTRL", SHIFT: "SHIFT",
    CAPS: "CAPS", MOD2: "MOD2", MOD3: "MOD3", MOD5: "MOD5"
};

function settings(raw) {
    var out = {};
    for (var k in DEFAULTS) {
        var v = raw ? raw[k] : undefined;
        out[k] = typeof v === "boolean" ? v : DEFAULTS[k];
    }
    return out;
}

function splitCombo(combo) {
    return String(combo || "").split("+").map(function (p) { return p.trim(); }).filter(function (p) { return p !== ""; });
}

// canonical mirrors the Lua loader and horneroctl: aliased, sorted,
// upper-cased modifiers + lower-cased key. Only used for matching.
function canonical(combo) {
    var parts = splitCombo(combo);
    if (parts.length === 0)
        return "";
    var key = parts[parts.length - 1].toLowerCase();
    var mods = [];
    for (var i = 0; i < parts.length - 1; i++) {
        var raw = parts[i].toUpperCase().replace(/^\$/, "");
        var name = MOD_ALIASES[raw] || raw;
        if (mods.indexOf(name) < 0)
            mods.push(name);
    }
    mods.sort();
    return mods.length ? mods.join(" + ") + " + " + key : key;
}

function categoryInfo(name) {
    var info = CATEGORIES[name];
    if (info)
        return info;
    if (String(name).indexOf("Submap: ") === 0)
        return { glyph: "keyframes", es: "Submapa " + String(name).slice(8), order: 20 };
    return { glyph: "keyboard", es: name, order: 30 };
}

// friendlyAction turns the config's dispatcher text into something a
// person reads: the command for exec_cmd, the dispatcher path otherwise.
function friendlyAction(action) {
    var a = String(action || "").trim();
    var exec = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"\)$/.exec(a);
    if (exec)
        return exec[1].replace(/\\"/g, "\"");
    var fn = /^function\s*\(\)\s*(.*?)\s*end$/.exec(a);
    if (fn) {
        var call = /([A-Za-z_][\w.]*)\(/.exec(fn[1]);
        return call ? call[1].replace(/^(helpers|hornero_helpers)\./, "") : fn[1];
    }
    if (a.indexOf("hl.dsp.") === 0)
        a = a.slice(7);
    return a;
}

function normalise(raw) {
    var list = [];
    try {
        list = typeof raw === "string" ? JSON.parse(raw) : (raw || []);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list))
        return [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var e = list[i] || {};
        var submap = String(e.submap || "");
        if (submap.indexOf(HIDDEN_SUBMAP_PREFIX) === 0)
            continue;
        if (isBadgeGlobal({ action: String(e.action || ""), dispatcher: String(e.dispatcher || ""), label: "" }))
            continue;
        var category = String(e.category || "") || "General";
        var info = categoryInfo(category);
        out.push({
            combo: String(e.combo || ""),
            original: String(e.original || ""),
            category: category,
            categoryEs: info.es,
            glyph: info.glyph,
            order: info.order,
            action: String(e.action || ""),
            label: friendlyAction(e.action || e.dispatcher),
            submap: submap,
            source: String(e.source || ""),
            dispatcher: String(e.dispatcher || ""),
            remapped: e.remapped === true,
            mouse: e.mouse === true || String(e.combo || "").indexOf("mouse") >= 0,
            keys: splitCombo(e.combo),
            shared: 1
        });
    }
    // Hyprland fires every bind on a combo; name the combos that carry
    // more than one global bind so the overlay can flag them.
    var counts = {};
    for (var j = 0; j < out.length; j++) {
        if (out[j].submap === "") {
            var c = canonical(out[j].combo);
            counts[c] = (counts[c] || 0) + 1;
        }
    }
    for (var k = 0; k < out.length; k++) {
        if (out[k].submap === "")
            out[k].shared = counts[canonical(out[k].combo)];
    }
    return out;
}

// matches: every whitespace-separated token must hit the combo, the
// action, or the category in English or Spanish.
function matches(entry, query) {
    var q = String(query || "").trim().toLowerCase();
    if (q === "")
        return true;
    var hay = [entry.combo, entry.label, entry.action, entry.category, entry.categoryEs, entry.submap].join(" ").toLowerCase();
    var tokens = q.split(/\s+/);
    for (var i = 0; i < tokens.length; i++) {
        if (hay.indexOf(tokens[i]) < 0)
            return false;
    }
    return true;
}

function visible(entry, opts) {
    var o = settings(opts);
    if (!o.showSubmaps && entry.submap !== "")
        return false;
    if (!o.showMouse && entry.mouse)
        return false;
    return true;
}

// grouped returns [{ name, es, glyph, rows }] ordered by purpose.
function grouped(entries, query, opts) {
    var byName = {};
    var groups = [];
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (!visible(e, opts) || !matches(e, query))
            continue;
        var name = e.submap !== "" && e.category.indexOf("Submap: ") !== 0 ? e.category + " · " + e.submap : e.category;
        if (!byName[name]) {
            byName[name] = { name: name, es: e.categoryEs, glyph: e.glyph, order: e.order, rows: [] };
            groups.push(byName[name]);
        }
        byName[name].rows.push(e);
    }
    groups.sort(function (a, b) { return a.order - b.order; });
    return groups;
}

function flatten(groups) {
    var out = [];
    for (var i = 0; i < groups.length; i++)
        for (var j = 0; j < groups[i].rows.length; j++)
            out.push(groups[i].rows[j]);
    return out;
}

// conflictFor returns the global entry already on `combo` (ignoring the
// bind being moved), or null.
function conflictFor(entries, combo, movingCombo) {
    var c = canonical(combo);
    var self = canonical(movingCombo);
    if (c === "" || c === self)
        return null;
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e.submap === "" && canonical(e.combo) === c)
            return e;
    }
    return null;
}

// summonCombo finds the bind that opens this overlay.
function summonCombo(entries) {
    for (var i = 0; i < entries.length; i++) {
        var a = entries[i].action;
        if (entries[i].submap === "" && (a.indexOf("keyboard keys") >= 0 || a.indexOf("keybinds toggle") >= 0))
            return entries[i].combo;
    }
    return "";
}

// --- key capture --------------------------------------------------------
// Qt key codes (Qt.Key_*) to xkb keysym names Hyprland binds use.
var QT_KEYS = {
    0x01000000: "escape", 0x01000001: "Tab", 0x01000003: "BackSpace", 0x01000004: "Return",
    0x01000005: "Return", 0x01000006: "Insert", 0x01000007: "Delete", 0x01000009: "Print",
    0x01000010: "Home", 0x01000011: "End", 0x01000012: "left", 0x01000013: "up",
    0x01000014: "right", 0x01000015: "down", 0x01000016: "Prior", 0x01000017: "Next",
    0x20: "Space", 0x21: "exclam", 0x22: "quotedbl", 0x23: "numbersign", 0x24: "dollar",
    0x25: "percent", 0x26: "ampersand", 0x27: "apostrophe", 0x28: "parenleft", 0x29: "parenright",
    0x2a: "asterisk", 0x2b: "plus", 0x2c: "comma", 0x2d: "minus", 0x2e: "period", 0x2f: "slash",
    0x3a: "colon", 0x3b: "semicolon", 0x3c: "less", 0x3d: "equal", 0x3e: "greater", 0x3f: "question",
    0x40: "at", 0x5b: "bracketleft", 0x5c: "backslash", 0x5d: "bracketright", 0x5f: "underscore",
    0x60: "grave", 0x7b: "braceleft", 0x7c: "bar", 0x7d: "braceright", 0x7e: "asciitilde",
    0x01000070: "XF86AudioLowerVolume", 0x01000071: "XF86AudioMute", 0x01000072: "XF86AudioRaiseVolume",
    0x01000080: "XF86AudioPlay", 0x01000081: "XF86AudioStop", 0x01000082: "XF86AudioPrev",
    0x01000083: "XF86AudioNext", 0x010000b2: "XF86MonBrightnessUp", 0x010000b3: "XF86MonBrightnessDown"
};
var QT_MODIFIER_KEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000024, 0x01000053, 0x01000054, 0x01001103];
var QT_SHIFT = 0x02000000, QT_CTRL = 0x04000000, QT_ALT = 0x08000000, QT_META = 0x10000000;

// comboFromKey builds "SUPER + SHIFT + X" from a key event; "" while
// only modifiers are held (keep listening).
function comboFromKey(key, modifiers) {
    if (QT_MODIFIER_KEYS.indexOf(key) >= 0)
        return "";
    var name = QT_KEYS[key];
    if (!name) {
        if (key >= 0x41 && key <= 0x5a)
            name = String.fromCharCode(key);
        else if (key >= 0x30 && key <= 0x39)
            name = String.fromCharCode(key);
        else if (key >= 0x01000030 && key <= 0x01000052)
            name = "F" + (key - 0x01000030 + 1);
        else
            return "";
    }
    var mods = [];
    if (modifiers & QT_META)
        mods.push("SUPER");
    if (modifiers & QT_CTRL)
        mods.push("CTRL");
    if (modifiers & QT_ALT)
        mods.push("ALT");
    if (modifiers & QT_SHIFT)
        mods.push("SHIFT");
    return mods.concat([name]).join(" + ");
}

// luaString quotes a combo for `hyprctl eval 'hornero_keybinds.run(...)'`.
function luaString(s) {
    return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, " ") + "\"";
}

function runExpression(entry) {
    return "hornero_keybinds.run(" + luaString(entry.combo) + ")";
}

// execCommand is the fallback runner for non-Lua sessions.
function execCommand(entry) {
    var m = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"\)$/.exec(String(entry.action || "").trim());
    if (m)
        return m[1].replace(/\\"/g, "\"");
    var h = /^exec,\s*(.+)$/.exec(String(entry.action || "").trim());
    return h ? h[1] : "";
}

// --- SUPER-hold badges (#701) -------------------------------------------
// The compositor reports bare-Super through three non-consuming
// `global` binds (HorneroOS/config keybindings-overlay.lua):
// superHoldArm on Super press, superHoldRelease on a bare release, and
// superHoldInterrupt whenever any SUPER combo fires. None of them
// consumes the keypress, so every SUPER combo still runs unchanged.
// holdStep is the whole state machine, driven by services/Keybinds.qml
// with wall-clock ms: press arms, tick promotes after holdMs, combo
// (interrupt) or release hides, and a missed release cannot strand
// the badges past BADGE_MAX_SHOWN_MS.
function holdState() {
    return { phase: "idle", since: 0, visible: false };
}

function holdStep(state, event, opts, now) {
    var o = badgeSettings(opts);
    var s = { phase: state ? state.phase : "idle", since: state ? state.since : 0 };
    if (event === "press") {
        s = o.enabled ? { phase: "armed", since: now } : { phase: "idle", since: 0 };
    } else if (event === "interrupt") {
        if (s.phase === "armed" || s.phase === "shown")
            s.phase = "used";
    } else if (event === "release") {
        s = { phase: "idle", since: 0 };
    } else if (event === "tick") {
        if (!o.enabled)
            s = { phase: "idle", since: 0 };
        else if (s.phase === "armed" && now - s.since >= o.holdMs)
            s.phase = "shown";
        else if (s.phase === "shown" && now - s.since >= o.holdMs + BADGE_MAX_SHOWN_MS)
            s.phase = "used";
    }
    s.visible = s.phase === "shown";
    return s;
}

// superBadges lists the bare SUPER + <key> global binds (no extra
// modifier, no submap, no mouse): one badge per key, first bind wins.
function superBadges(entries) {
    var seen = {};
    var out = [];
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e.submap !== "" || e.mouse || isBadgeGlobal(e))
            continue;
        var parts = splitCombo(e.combo);
        if (parts.length !== 2)
            continue;
        var mod = MOD_ALIASES[parts[0].toUpperCase().replace(/^\$/, "")] || parts[0].toUpperCase();
        if (mod !== "SUPER")
            continue;
        var key = parts[1];
        if (seen[key.toLowerCase()])
            continue;
        seen[key.toLowerCase()] = true;
        out.push({ key: key, label: e.label, combo: e.combo, category: e.category, order: e.order });
    }
    out.sort(function (a, b) { return a.order - b.order; });
    return out;
}

// workspaceBadges maps a workspace id to the key that focuses it with
// bare SUPER, parsed from the live bind's action
// (`hl.dsp.focus({ workspace = "10" })`), so rebinds move the badge.
function workspaceBadges(entries) {
    var out = {};
    var badges = superBadges(entries);
    var byCombo = {};
    for (var i = 0; i < entries.length; i++)
        byCombo[entries[i].combo] = entries[i];
    for (var j = 0; j < badges.length; j++) {
        var e = byCombo[badges[j].combo];
        var m = /^hl\.dsp\.focus\(\{\s*workspace\s*=\s*"(\d+)"\s*\}\)$/.exec(String(e ? e.action : "").trim());
        if (!m)
            m = /^workspace,\s*(\d+)$/.exec(String(e ? e.action : "").trim());
        if (m && out[m[1]] === undefined)
            out[m[1]] = badges[j].key;
    }
    return out;
}
