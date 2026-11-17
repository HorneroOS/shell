.pragma library

// Hornero Chromatic client-side colour helpers (RFC 0002 §13.2, contract
// §7.1). Pure model, executed under node by tests/test_chromatic_ui_*.py.
//
// The engine (Hornero.Chromatic, C++) is authoritative for palette
// synthesis. This file only does what the shell must do without it:
// interpolate between two palettes in OKLab for the palette transition,
// and answer WCAG questions for PluginKit and the specimen board when the
// engine module is not loaded. Nothing here produces a palette.

var ROLES = ["ground", "sunken", "base", "panel", "raised", "lifted", "ink", "inkMuted", "inkFaint", "rule", "ruleStrong", "focus", "signal", "glow", "onSignal", "signalWell", "onSignalWell", "cue", "onCue", "cueWell", "onCueWell", "phosphor", "onPhosphor", "phosphorWell", "onPhosphorWell", "alert", "onAlert", "alertWell", "onAlertWell", "inverse", "onInverse", "inverseSignal", "scrim", "shadow"];

// Palette transition budget (RFC 0002 §13.2): at most 240 ms in at most 12
// discrete steps; STEP_MS is the Timer interval.
var MAX_STEPS = 12;
var STEP_MS = 20;

function isHex(h) {
    return /^#[0-9A-Fa-f]{6}$/.test(String(h));
}

function _srgbToLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function _linearToSrgb(c) {
    var v = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
    return Math.max(0, Math.min(1, v));
}

// "#RRGGBB" of a QML color (or any string Qt prints as #rrggbb or
// #aarrggbb); anything else comes back unchanged.
function toHex(c) {
    var t = String(c);
    if (/^#[0-9A-Fa-f]{8}$/.test(t))
        t = "#" + t.substr(3);
    return /^#[0-9A-Fa-f]{6}$/.test(t) ? t.toUpperCase() : t;
}

function hexToRgb(h) {
    return [parseInt(h.substr(1, 2), 16) / 255, parseInt(h.substr(3, 2), 16) / 255, parseInt(h.substr(5, 2), 16) / 255];
}

function rgbToHex(rgb) {
    var out = "#";
    for (var i = 0; i < 3; i++) {
        var v = Math.round(Math.max(0, Math.min(1, rgb[i])) * 255);
        out += (v < 16 ? "0" : "") + v.toString(16).toUpperCase();
    }
    return out;
}

function hexToOklab(h) {
    var c = hexToRgb(h);
    var r = _srgbToLinear(c[0]);
    var g = _srgbToLinear(c[1]);
    var b = _srgbToLinear(c[2]);
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
}

function oklabToRgb(lab) {
    var l = lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2];
    var m = lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2];
    var s = lab[0] - 0.0894841775 * lab[1] - 1.291485548 * lab[2];
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;
    return [_linearToSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), _linearToSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s), _linearToSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)];
}

// Linear OKLab interpolation of two #RRGGBB colours.
function mixHex(a, b, t) {
    if (!isHex(a) || !isHex(b))
        return isHex(b) ? b : a;
    if (t <= 0)
        return a.toUpperCase();
    if (t >= 1)
        return b.toUpperCase();
    var x = hexToOklab(a);
    var y = hexToOklab(b);
    return rgbToHex(oklabToRgb([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t]));
}

function relativeLuminance(h) {
    var c = hexToRgb(h);
    return 0.2126 * _srgbToLinear(c[0]) + 0.7152 * _srgbToLinear(c[1]) + 0.0722 * _srgbToLinear(c[2]);
}

// WCAG 2.x contrast ratio of two #RRGGBB colours.
function contrast(a, b) {
    var la = relativeLuminance(a);
    var lb = relativeLuminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// Move `fg` along OKLab lightness only (keeping a and b) until it reaches
// `min`:1 on `bg`; the direction is the one that gains contrast. Returns
// `fg` unchanged when it already passes, and the extreme (black or white)
// when `min` cannot be reached.
function ensureContrast(fg, bg, min) {
    if (!isHex(fg) || !isHex(bg))
        return fg;
    if (contrast(fg, bg) >= min)
        return String(fg).toUpperCase();
    var lab = hexToOklab(fg);
    var lighter = relativeLuminance(bg) < 0.18;
    var lo = lighter ? lab[0] : 0;
    var hi = lighter ? 1 : lab[0];
    var best = rgbToHex(oklabToRgb([lighter ? 1 : 0, lab[1], lab[2]]));
    for (var i = 0; i < 30; i++) {
        var mid = (lo + hi) / 2;
        var cand = rgbToHex(oklabToRgb([mid, lab[1], lab[2]]));
        if (contrast(cand, bg) >= min) {
            best = cand;
            if (lighter)
                hi = mid;
            else
                lo = mid;
        } else if (lighter) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return best;
}

// "#RRGGBB" for an OKLCH colour (hue in degrees), clamped into sRGB by
// reducing chroma at fixed lightness and hue. Only for UI affordances
// (the manual accent picker); palette synthesis is the engine's job.
function oklchHex(L, C, h) {
    var rad = h * Math.PI / 180;
    var c = C;
    for (var i = 0; i < 24; i++) {
        var a = c * Math.cos(rad);
        var b = c * Math.sin(rad);
        var l = L + 0.3963377774 * a + 0.2158037573 * b;
        var m = L - 0.1055613458 * a - 0.0638541728 * b;
        var s = L - 0.0894841775 * a - 1.291485548 * b;
        l = l * l * l;
        m = m * m * m;
        s = s * s * s;
        var r = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s];
        if (Math.min(r[0], r[1], r[2]) >= -0.0005 && Math.max(r[0], r[1], r[2]) <= 1.0005)
            break;
        c *= 0.9;
    }
    return rgbToHex(oklabToRgb([L, c * Math.cos(rad), c * Math.sin(rad)]));
}

// Hue (degrees, [0,360)), chroma and lightness of a #RRGGBB colour.
function hexToHueChroma(h) {
    var lab = hexToOklab(h);
    var hue = Math.atan2(lab[2], lab[1]) * 180 / Math.PI;
    return { hue: hue < 0 ? hue + 360 : hue, chroma: Math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]), lightness: lab[0] };
}

// Flat {role: "#RRGGBB", term0..term15} view of a schema-v2 scheme object.
// `glow` falls back to `signal` as in Signal.optionalRoles.
function flatten(scheme) {
    var out = {};
    var palette = (scheme && scheme.palette) || {};
    for (var i = 0; i < ROLES.length; i++) {
        var role = ROLES[i];
        var v = palette[role];
        if (!v && role === "glow")
            v = palette.signal;
        if (isHex(v))
            out[role] = String(v).toUpperCase();
    }
    var terminal = (scheme && Array.isArray(scheme.terminal)) ? scheme.terminal : [];
    for (var t = 0; t < 16 && t < terminal.length; t++) {
        if (isHex(terminal[t]))
            out["term" + t] = String(terminal[t]).toUpperCase();
    }
    return out;
}

// Number of transition steps for a duration; 0 means "apply instantly".
function stepsFor(durationMs) {
    if (!(durationMs > 0))
        return 0;
    return Math.max(1, Math.min(MAX_STEPS, Math.round(durationMs / STEP_MS)));
}

// Interpolated flat palette at `step` of `steps` (1-based; step === steps
// is the exact target). Keys missing from `from` jump to the target.
function frame(from, to, step, steps) {
    var t = steps > 0 ? Math.min(1, step / steps) : 1;
    var out = {};
    for (var k in to) {
        if (!Object.prototype.hasOwnProperty.call(to, k))
            continue;
        out[k] = (t >= 1 || !from || !from[k]) ? to[k] : mixHex(from[k], to[k], t);
    }
    return out;
}

// The user's accent (appearance.accent, RFC 0001 amendment: user colour
// choice) laid over a flattened palette: the accent role, its glow, the
// text that sits on it and its well. Only the accent family changes, so
// structure, ground, ink and status colours keep the theme's own gates.
// `hex` must be #RRGGBB; anything else returns the palette untouched.
function withAccent(flat, hex) {
    if (!isHex(hex) || !flat || !flat.ground || !flat.ink)
        return flat;
    var accent = String(hex).toUpperCase();
    var out = {};
    for (var k in flat) {
        if (Object.prototype.hasOwnProperty.call(flat, k))
            out[k] = flat[k];
    }
    var well = mixHex(flat.panel || flat.ground, accent, 0.28);
    out.signal = accent;
    out.glow = accent;
    out.onSignal = contrast(accent, flat.ground) >= contrast(accent, flat.ink) ? flat.ground : flat.ink;
    out.signalWell = well;
    out.onSignalWell = contrast(well, flat.ink) >= contrast(well, flat.ground) ? flat.ink : flat.ground;
    return out;
}

// Which accent applies: an experience-mode choice beats a colour-mode
// choice, which beats the global one; "" means the theme's own accent.
function resolveAccent(prefs, experienceMode, themeMode) {
    var p = prefs || {};
    var byExp = p.perExperience || {};
    var byMode = p.perMode || {};
    var order = [byExp[experienceMode], byMode[themeMode], p.color];
    for (var i = 0; i < order.length; i++) {
        if (isHex(order[i]))
            return String(order[i]).toUpperCase();
    }
    return "";
}

// Read-only status for PluginKit `Theme.chromatic`; never carries paths.
function status(scheme) {
    var c = scheme && scheme.chromatic;
    if (!c || typeof c !== "object")
        return null;
    var resolved = c.resolved || {};
    return {
        "active": true,
        "variant": String(resolved.variant || (c.request && c.request.variant) || ""),
        "mode": String(resolved.mode || scheme.mode || ""),
        "seeds": Array.isArray(c.seeds) ? c.seeds.filter(isHex).map(function (s) {
            return String(s).toUpperCase();
        }) : [],
        "fingerprint": String(c.fingerprint || "")
    };
}

var ALPHA_ROLES = ["base", "panel", "raised", "lifted", "sunken"];

// Sanitised `minSurfaceAlpha` block: role -> 0..1, unknown keys dropped.
function cleanMinSurfaceAlpha(block) {
    var out = {};
    if (!block || typeof block !== "object")
        return out;
    for (var i = 0; i < ALPHA_ROLES.length; i++) {
        var v = block[ALPHA_ROLES[i]];
        if (typeof v === "number" && isFinite(v))
            out[ALPHA_ROLES[i]] = Math.max(0, Math.min(1, v));
    }
    return out;
}

var CLEARINK_KEYS = ["ink", "inkMuted", "signal", "alert", "halo"];

// Sanitised `clearInk` block, or null when either polarity is incomplete.
function cleanClearInk(block) {
    if (!block || typeof block !== "object")
        return null;
    var out = {};
    var sides = ["light", "dark"];
    for (var s = 0; s < sides.length; s++) {
        var side = block[sides[s]];
        if (!side || typeof side !== "object")
            return null;
        var set = {};
        for (var i = 0; i < CLEARINK_KEYS.length; i++) {
            if (!isHex(side[CLEARINK_KEYS[i]]))
                return null;
            set[CLEARINK_KEYS[i]] = String(side[CLEARINK_KEYS[i]]).toUpperCase();
        }
        out[sides[s]] = set;
    }
    return out;
}
