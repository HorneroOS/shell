.pragma library

// Reload cover policy: palette, settings and copy, as pure functions so
// tests can run them under node. Deliberately self-contained: the cover
// must load even when the main shell config is broken, so nothing here
// imports shell modules. The built-in tables are copies of the Signal
// roles the cover paints (services/Signal.qml builtInThemes); tests keep
// them in sync.

// Roles the cover paints. A live scheme missing any of them (or carrying
// a malformed value) is ignored as a whole: a half-applied palette could
// put ink on ink.
var ROLES = ["ground", "sunken", "panel", "raised", "ink", "inkMuted", "inkFaint", "rule", "ruleStrong", "signal", "signalWell", "onSignalWell", "cue", "phosphor", "alert"];

var NIGHT = {
    "ground": "#0C1016",
    "sunken": "#10151C",
    "panel": "#1B2430",
    "raised": "#24303D",
    "ink": "#E6EBF1",
    "inkMuted": "#A9B7C6",
    "inkFaint": "#8999AB",
    "rule": "#2D3B4B",
    "ruleStrong": "#8393A6",
    "signal": "#F2AC52",
    "signalWell": "#3D2B12",
    "onSignalWell": "#FFE0B0",
    "cue": "#8BCEF0",
    "phosphor": "#8DDBAF",
    "alert": "#FF8494"
};

var DAY = {
    "ground": "#E8EDF4",
    "sunken": "#E0E6EF",
    "panel": "#F5F8FC",
    "raised": "#FCFCFE",
    "ink": "#283344",
    "inkMuted": "#505E70",
    "inkFaint": "#606D80",
    "rule": "#D2DAE6",
    "ruleStrong": "#7A8798",
    "signal": "#864700",
    "signalWell": "#FCE9C8",
    "onSignalWell": "#432300",
    "cue": "#145D86",
    "phosphor": "#1E6448",
    "alert": "#9C293E"
};

var CONTRAST = {
    "ground": "#000000",
    "sunken": "#050607",
    "panel": "#101317",
    "raised": "#181C21",
    "ink": "#FFFFFF",
    "inkMuted": "#E2E4E6",
    "inkFaint": "#A9AEB4",
    "rule": "#8A939C",
    "ruleStrong": "#FFFFFF",
    "signal": "#FFC247",
    "signalWell": "#3D2C00",
    "onSignalWell": "#FFE3A6",
    "cue": "#8FD3FF",
    "phosphor": "#9BF0AE",
    "alert": "#FF8A73"
};

var BUILTINS = {
    "hornero-signal-night": {"mode": "dark", "palette": NIGHT},
    "hornero-signal-day": {"mode": "light", "palette": DAY},
    "hornero-signal-contrast": {"mode": "dark", "palette": CONTRAST}
};

var HEX = /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/;

function parse(text) {
    if (typeof text !== "string" || text.length === 0)
        return null;
    try {
        var v = JSON.parse(text);
        return v !== null && typeof v === "object" && !Array.isArray(v) ? v : null;
    } catch (e) {
        return null;
    }
}

function pick(obj, path, fallback) {
    var cur = obj;
    for (var i = 0; i < path.length; i++) {
        if (cur === null || typeof cur !== "object" || !(path[i] in cur))
            return fallback;
        cur = cur[path[i]];
    }
    return typeof cur === typeof fallback ? cur : fallback;
}

function copy(table) {
    var out = {};
    for (var i = 0; i < ROLES.length; i++)
        out[ROLES[i]] = table[ROLES[i]];
    return out;
}

// Validated role table from a parsed scheme (schema v2), or null.
function schemePalette(scheme) {
    if (scheme === null || typeof scheme.palette !== "object" || scheme.palette === null)
        return null;
    var out = {};
    for (var i = 0; i < ROLES.length; i++) {
        var v = scheme.palette[ROLES[i]];
        if (typeof v !== "string" || !HEX.test(v))
            return null;
        out[ROLES[i]] = v;
    }
    return out;
}

// Everything the cover needs from the user's live state.
//   schemeText: $XDG_STATE_HOME/hornero/signal/scheme.json (may be "")
//   shellText:  $XDG_CONFIG_HOME/hornero/shell.json (may be "")
// Never throws; worst case is Signal Night with default settings.
function resolve(schemeText, shellText) {
    var shell = parse(shellText);
    var scheme = parse(schemeText);
    var highContrast = pick(shell, ["appearance", "highContrast"], false) === true;
    var themeId = pick(shell, ["appearance", "theme"], "");
    var palette = null;
    var mode = "dark";
    var source = "fallback";
    if (highContrast) {
        // Same rule as Signal.palette: High Contrast overrides the theme.
        palette = copy(CONTRAST);
        source = "contrast";
    } else {
        palette = schemePalette(scheme);
        if (palette !== null) {
            mode = scheme.mode === "light" ? "light" : "dark";
            source = "scheme";
        } else if (themeId in BUILTINS) {
            palette = copy(BUILTINS[themeId].palette);
            mode = BUILTINS[themeId].mode;
            source = "builtin";
        } else {
            palette = copy(NIGHT);
        }
    }
    return {
        "palette": palette,
        "light": mode === "light",
        "highContrast": highContrast,
        "source": source,
        "reducedMotion": pick(shell, ["appearance", "reducedMotion"], false) === true,
        "mascot": pick(shell, ["appearance", "atmosphere", "mascot"], true) !== false,
        "sans": pick(shell, ["appearance", "font", "family", "sans"], "IBM Plex Sans") || "IBM Plex Sans",
        "mono": pick(shell, ["appearance", "font", "family", "mono"], "IBM Plex Mono") || "IBM Plex Mono",
        "display": pick(shell, ["appearance", "font", "family", "display"], "IBM Plex Sans Condensed") || "IBM Plex Sans Condensed"
    };
}

// "es" for any Spanish locale, else "en". Takes the first non-empty of
// the usual locale variables (LANGUAGE may be a colon list) and finally
// Qt's own locale name.
function language(candidates) {
    for (var i = 0; i < candidates.length; i++) {
        var c = candidates[i];
        if (typeof c !== "string" || c.length === 0)
            continue;
        var first = c.split(":")[0].toLowerCase();
        if (first === "c" || first === "posix" || first.indexOf("c.") === 0)
            continue;
        return first.indexOf("es") === 0 ? "es" : "en";
    }
    return "en";
}

var COPY = {
    "es": {
        "title": "ESPERE",
        "aside": "STAND BY",
        "channel": "CANAL 00 · SHELL",
        "status": "Reiniciando el shell · tus ventanas siguen intactas",
        "slow": "Está tardando más de lo normal · revisá «horneroctl shell logs»",
        "quiet": "EN ESPERA",
        "tally": "EN PAUSA"
    },
    "en": {
        "title": "STAND BY",
        "aside": "ESPERE",
        "channel": "CHANNEL 00 · SHELL",
        "status": "Restarting the shell · your windows are untouched",
        "slow": "Taking longer than usual · check “horneroctl shell logs”",
        "quiet": "STANDING BY",
        "tally": "OFF AIR"
    }
};

function text(lang, key) {
    var table = COPY[lang] || COPY.en;
    return table[key] || COPY.en[key] || "";
}

// Monitor name to treat as primary: Hyprland's focused monitor when the
// `hyprctl -j monitors` output names one, else the first screen.
function primaryScreen(monitorsJson, screenNames) {
    var first = screenNames.length > 0 ? screenNames[0] : "";
    var list = null;
    try {
        list = JSON.parse(monitorsJson);
    } catch (e) {
        return first;
    }
    if (!Array.isArray(list))
        return first;
    for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].focused === true && screenNames.indexOf(list[i].name) !== -1)
            return list[i].name;
    }
    return first;
}

// Elapsed seconds as a broadcast timecode readout: T+MM:SS.
function timecode(seconds) {
    var s = Math.max(0, Math.floor(seconds));
    var m = Math.floor(s / 60);
    s = s % 60;
    return "T+" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
}
