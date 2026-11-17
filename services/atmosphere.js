.pragma library

// Atmosphere model (visual language section 17): the warm, cosy layer of
// the Signal surfaces. Pure functions, executed under node by
// tests/test_atmosphere.py; services/Atmosphere.qml binds them to the
// palette and the user's settings.
//
// Nothing here draws anything. It (1) validates the user's knobs, (2)
// derives two accent "chips" from whatever palette is active, so custom
// and Chromatic palettes get a lamp and a blush too, and (3) turns the
// knobs into the small alpha values the surfaces use. Every alpha has a
// hard ceiling, so a hand-edited shell.json cannot exceed the language.

var TONES = ["cozy", "plain"];
var DEFAULTS = {
    enabled: true, lamp: 0.8, warmth: 0.2, innerLight: 0.8, vignette: 0.4,
    grain: 0.3, scanlines: 0, plateTracking: 0.14, mascot: true, tone: "cozy"
};
// Ranges mirror the Control Center sliders (Appearance > Atmosphere).
var RANGES = {
    lamp: [0, 1.5], warmth: [0, 1], innerLight: [0, 1.5],
    vignette: [0, 1], grain: [0, 1], scanlines: [0, 1], plateTracking: [0, 0.3]
};

// Alpha at knob = 1 and the ceiling at the knob maximum. The lamp is a
// wash of light, not an emissive halo (section 9 limits halos to 40 %).
var ALPHA = {
    lamp: 0.14, innerLight: 0.07, vignette: 0.28, grain: 0.14, scanlines: 0.06
};
var CEILING = {
    lamp: 0.20, innerLight: 0.10, vignette: 0.30, grain: 0.14, scanlines: 0.06
};

function _num(v, lo, hi, def) {
    var n = typeof v === "number" ? v : parseFloat(v);
    if (!isFinite(n))
        return def;
    return Math.max(lo, Math.min(hi, n));
}

// Normalise whatever the config holds: unknown tone -> "cozy" (factory),
// numbers clamped to the slider ranges, booleans coerced.
function clean(raw) {
    var r = raw || {};
    var out = {
        enabled: r.enabled === undefined ? DEFAULTS.enabled : r.enabled === true,
        mascot: r.mascot === undefined ? DEFAULTS.mascot : r.mascot === true,
        tone: TONES.indexOf(r.tone) >= 0 ? r.tone : DEFAULTS.tone
    };
    for (var k in RANGES)
        out[k] = _num(r[k], RANGES[k][0], RANGES[k][1], DEFAULTS[k]);
    return out;
}

function isHex(h) {
    return /^#[0-9A-Fa-f]{6}$/.test(String(h));
}

function _rgb(h) {
    return [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)];
}

function _hex(c) {
    return "#" + c.map(function (v) {
        var s = Math.max(0, Math.min(255, Math.round(v))).toString(16).toUpperCase();
        return s.length < 2 ? "0" + s : s;
    }).join("");
}

// sRGB mix, t = 0 -> a, t = 1 -> b.
function mix(a, b, t) {
    var x = _rgb(a), y = _rgb(b);
    return _hex([0, 1, 2].map(function (i) {
        return x[i] + (y[i] - x[i]) * t;
    }));
}

function luminance(h) {
    var c = _rgb(h).map(function (v) {
        v /= 255;
        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

function minContrast(color, surfaces) {
    return Math.min.apply(null, surfaces.map(function (s) {
        return contrast(color, s);
    }));
}

// Pull `color` toward `ink` until it reads (>= min) on every surface.
// The contrast gates of the palette therefore also hold for the chips.
function readable(color, surfaces, ink, min) {
    var c = color;
    for (var i = 1; i <= 20 && minContrast(c, surfaces) < min; i++)
        c = mix(color, ink, i * 0.05);
    return c;
}

var SURFACE_ROLES = ["ground", "sunken", "base", "panel", "raised", "lifted"];

// The two accent chips. `lamp` follows the palette's emission colour
// (glow, falling back to signal) and slides toward `blush` with the
// warmth knob; `blush` is a dusty rose derived from alert + the palette's
// magenta/lavender terminal slot. Both are readable as text on all six
// surfaces (AA 4.5:1), including in custom palettes.
function chips(palette, warmth) {
    var surfaces = SURFACE_ROLES.map(function (r) {
        return String(palette[r]);
    });
    var ink = String(palette.ink);
    var glow = isHex(palette.glow) ? String(palette.glow) : String(palette.signal);
    var rose = isHex(palette.term5) ? mix(String(palette.alert), String(palette.term5), 0.5) : String(palette.alert);
    var blush = readable(rose, surfaces, ink, 4.5);
    var lamp = readable(mix(glow, blush, _num(warmth, 0, 1, 0)), surfaces, ink, 4.5);
    // `alertText`: alert pulled toward ink until it reads on every surface,
    // including tooltips (`lifted`), where some palettes sit under 4.5:1.
    var alertText = readable(String(palette.alert), surfaces, ink, 4.5);
    return {lamp: lamp, blush: blush, alertText: alertText};
}

// Knobs -> alphas for one render. `light` drops the dark-only parts
// (vignette, scanlines) and halves the lamp: a warm paper glow, not a lamp.
// `lowPower` (power-saver profile) drops lamp, vignette, grain and
// scanlines, keeping only the soft inner highlight.
function levels(cfg, light, lowPower) {
    var c = clean(cfg);
    function a(k) {
        return Math.min(CEILING[k], ALPHA[k] * c[k]);
    }
    var on = c.enabled;
    var lp = lowPower === true;
    return {
        enabled: on,
        lamp: on && !lp ? a("lamp") * (light ? 0.5 : 1) : 0,
        innerLight: on ? a("innerLight") * (light ? 0.6 : 1) : 0,
        vignette: on && !light && !lp ? a("vignette") : 0,
        grain: on && !lp ? a("grain") : 0,
        scanlines: on && !light && !lp ? a("scanlines") : 0
    };
}
