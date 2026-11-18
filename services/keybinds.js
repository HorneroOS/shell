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
            keys: splitCombo(e.combo)
        });
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
