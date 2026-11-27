.pragma library

// Cockpit Clear adaptive ink (signal-visual-language §12).
//
// Pure model, executed under node by tests/test_clearink.py. Cockpit Clear
// draws no bar background at all, so legibility comes only from the
// foreground: per region, pick the polarity (the theme's own Night or Day
// foreground roles) with the larger contrast against the wallpaper mean,
// then add a glyph-only halo / soft shadow. Wallpapers never recolour the
// UI: polarity only chooses between two fixed role sets (RFC §9).

// Night roles ("light" ink on dark wallpaper regions) and Day roles
// ("dark" ink on bright regions); values mirror services/Signal.qml.
var LIGHT = {
    polarity: "light",
    ink: "#E6EBF1",
    inkMuted: "#A9B7C6",
    signal: "#FFC06B",
    alert: "#FF8494",
    halo: "#0C1016"
};

var DARK = {
    polarity: "dark",
    ink: "#283344",
    inkMuted: "#505E70",
    signal: "#864700",
    alert: "#9C293E",
    halo: "#FFFFFF"
};

var STYLES = ["auto", "outline", "shadow", "contrast"];
var DEFAULT_STYLE = "auto";

// §12.1 step 4: peak halo alpha and the deviation above which detailed
// wallpapers get the soft shadow too. The ring is near opaque: a thinner
// alpha lets a vivid wallpaper through and drops the foreground below 4.5:1.
var HALO_ALPHA = 0.96;
// Soft styles (Auto, Shadow): a gaussian-like shadow, never a hard ring. The
// foreground keeps its own colour; the shadow only darkens (or lightens) the
// wallpaper right next to the strokes so thin text and icons stay readable
// on a vivid wallpaper without any bar background.
var SOFT_ALPHA = 0.62;
var SOFT_ALPHA_BUSY = 0.74;
// Hairline rim of the Auto style, and the soft shadow's drop in px.
var RIM_ALPHA = 0.5;
var SHADOW_DROP = 1;
// Share of the soft shadow's alpha that reaches the pixels next to a thin
// stroke (the shader averages taps, so a hairline never reaches the peak).
var SHADOW_REACH = 0.5;
// Minimum contrast the preferred polarity must keep against the shadowed
// wallpaper before Auto flips to the opposite polarity: WCAG body text (4.5).
var KEEP_POLARITY = 4.5;
var POLARITIES = ["auto", "light", "dark"];
var DETAIL_DEVIATION = 0.12;
// §12.1 step 5: off meter segments are the polarity's ink at 30 %.
var OFF_SEGMENT_ALPHA = 0.3;
// Luminance grid width; rows follow the screen aspect.
var GRID_COLUMNS = 192;
// Region padding around every foreground element (§12.1 step 1).
var REGION_PAD = 2;

function isStyle(s) {
    return STYLES.indexOf(s) >= 0;
}

function normaliseStyle(s) {
    return isStyle(s) ? s : DEFAULT_STYLE;
}

function _hex(h) {
    return [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)];
}

function srgbToLinear(c8) {
    var c = c8 / 255;
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

// WCAG relative luminance of 8-bit sRGB.
function relativeLuminance(r, g, b) {
    return 0.2126 * srgbToLinear(r) + 0.7152 * srgbToLinear(g) + 0.0722 * srgbToLinear(b);
}

function hexLuminance(h) {
    var c = _hex(h);
    return relativeLuminance(c[0], c[1], c[2]);
}

function contrast(l1, l2) {
    var hi = Math.max(l1, l2);
    var lo = Math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
}

function rowsFor(width, height) {
    if (!(width > 0) || !(height > 0))
        return 0;
    return Math.max(1, Math.round(GRID_COLUMNS * height / width));
}

// Source rectangle (in image pixels) that covers a destination of aspect
// `dw`:`dh` the way Image.PreserveAspectCrop does (centred).
function coverRect(iw, ih, dw, dh) {
    if (!(iw > 0) || !(ih > 0) || !(dw > 0) || !(dh > 0))
        return null;
    var ia = iw / ih;
    var da = dw / dh;
    if (ia > da) {
        var w = ih * da;
        return { x: (iw - w) / 2, y: 0, width: w, height: ih };
    }
    var h = iw / da;
    return { x: 0, y: (ih - h) / 2, width: iw, height: h };
}

// `rgba` is a flat RGBA array (canvas ImageData.data). Returns a grid of
// per-cell relative luminance, or null when the data does not fit.
function buildGrid(rgba, cols, rows) {
    if (!rgba || cols <= 0 || rows <= 0 || rgba.length < cols * rows * 4)
        return null;
    var lum = new Array(cols * rows);
    for (var i = 0; i < cols * rows; i++) {
        var o = i * 4;
        lum[i] = relativeLuminance(rgba[o], rgba[o + 1], rgba[o + 2]);
    }
    return { cols: cols, rows: rows, lum: lum };
}

// Mean and standard deviation of the wallpaper under a screen-space
// rectangle (padded). Returns null without a grid or for an empty region.
function regionStats(grid, rect, screenWidth, screenHeight, pad) {
    if (!grid || !rect || !(screenWidth > 0) || !(screenHeight > 0))
        return null;
    var p = pad === undefined ? REGION_PAD : pad;
    var sx = grid.cols / screenWidth;
    var sy = grid.rows / screenHeight;
    var x0 = Math.max(0, Math.floor((rect.x - p) * sx));
    var y0 = Math.max(0, Math.floor((rect.y - p) * sy));
    var x1 = Math.min(grid.cols - 1, Math.ceil((rect.x + rect.width + p) * sx) - 1);
    var y1 = Math.min(grid.rows - 1, Math.ceil((rect.y + rect.height + p) * sy) - 1);
    if (x1 < x0 || y1 < y0)
        return null;
    var sum = 0;
    var sumSq = 0;
    var n = 0;
    for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
            var v = grid.lum[y * grid.cols + x];
            sum += v;
            sumSq += v * v;
            n++;
        }
    }
    var mean = sum / n;
    return { mean: mean, dev: Math.sqrt(Math.max(0, sumSq / n - mean * mean)), n: n };
}

// The two polarity role sets. A Chromatic scheme carries its own
// `clearInk` block ({light, dark}: ink, inkMuted, signal, alert, halo);
// without one the fixed Night/Day sets apply. Dynamic colour only ever
// changes these foreground colours: Clear still draws no background.
function setsFrom(clearInk) {
    if (!clearInk || !clearInk.light || !clearInk.dark)
        return { light: LIGHT, dark: DARK };
    var light = { polarity: "light" };
    var dark = { polarity: "dark" };
    var keys = ["ink", "inkMuted", "signal", "alert", "halo"];
    for (var i = 0; i < keys.length; i++) {
        light[keys[i]] = clearInk.light[keys[i]] || LIGHT[keys[i]];
        dark[keys[i]] = clearInk.dark[keys[i]] || DARK[keys[i]];
    }
    return { light: light, dark: dark };
}

function normalisePolarity(p) {
    return POLARITIES.indexOf(p) >= 0 ? p : "auto";
}

// Wallpaper luminance next to a stroke once the halo (`reach`: the alpha
// that arrives beside the stroke) is laid under it, in the polarity's own
// halo colour.
function shadowed(mean, set, reach) {
    var k = Math.max(0, Math.min(1, reach));
    return mean * (1 - k) + hexLuminance(set.halo) * k;
}

// Polarity of a region. Auto keeps the theme's own polarity (Night: light
// ink; Day: dark ink) for as long as it stays legible against the shadowed
// wallpaper, so a bar reads as one ink across most wallpapers; it flips to
// the other polarity only where the preferred one falls below KEEP_POLARITY.
// `forced` ("light" | "dark") is the user's override.
function polarityFor(mean, sets, themeLight, reach, forced) {
    var s = sets || { light: LIGHT, dark: DARK };
    var a = reach === undefined ? SOFT_ALPHA * SHADOW_REACH : reach;
    var pref = themeLight ? s.dark : s.light;
    var other = themeLight ? s.light : s.dark;
    // The halo only helps beside a stroke, so the ink must also hold its own
    // against the bare wallpaper (at a discount: 2.2 x the raw contrast).
    function score(set) {
        var ink = hexLuminance(set.ink);
        return Math.min(contrast(ink, shadowed(mean, set, a)), 2.2 * contrast(ink, mean));
    }
    var pc = score(pref);
    var oc = score(other);
    if (forced === "light" || forced === "dark") {
        var f = forced === "light" ? s.light : s.dark;
        return { set: f, contrast: f === pref ? pc : oc };
    }
    if (pc >= KEEP_POLARITY || pc >= oc)
        return { set: pref, contrast: pc };
    return { set: other, contrast: oc };
}

// The tone for one region. `stats` may be null (no wallpaper grid: video
// wallpaper, still loading); then polarity follows the theme and the shadow
// stays on at its busy strength, since nothing is known about detail.
// `style` is one of STYLES, `themeLight` the theme's own mode, `sets` the
// optional setsFrom(clearInk) result and `opts` the user's knobs:
// {strength: shadow/outline alpha multiplier, outline: ring width
// multiplier, polarity: "auto" | "light" | "dark"}.
function toneFor(stats, style, themeLight, sets, opts) {
    var s = sets || { light: LIGHT, dark: DARK };
    var o = opts || {};
    var st = normaliseStyle(style);
    var strength = Math.max(0, Math.min(1.5, o.strength === undefined || !isFinite(o.strength) ? 1 : o.strength));
    var ringScale = Math.max(0, Math.min(2, o.outline === undefined || !isFinite(o.outline) ? 1 : o.outline));
    var polarity = normalisePolarity(o.polarity);
    var detailed = stats ? stats.dev > DETAIL_DEVIATION : true;
    // Ring width / shadow radius in logical px, each with its own peak
    // alpha, and the shadow drop. Auto is a hairline rim plus a soft drop
    // shadow (a text-shadow, never a sticker outline); Outline is a firmer
    // ring only; Shadow is the soft shadow only; Contrast adds both and a
    // heavier weight. Legibility only ever comes from the foreground's own
    // halo, never from a bar background (RFC 0001 §5.1).
    var haloPx = 0;
    var shadowPx = 0;
    var ringAlpha = 0;
    var shadowAlpha = 0;
    var weight = 400;
    if (st === "auto") {
        haloPx = 1;
        ringAlpha = RIM_ALPHA;
        shadowPx = detailed ? 4 : 3;
        shadowAlpha = detailed ? SOFT_ALPHA_BUSY : SOFT_ALPHA;
    } else if (st === "outline") {
        haloPx = 1.5;
        ringAlpha = HALO_ALPHA;
    } else if (st === "shadow") {
        shadowPx = 4;
        shadowAlpha = SOFT_ALPHA_BUSY;
    } else if (st === "contrast") {
        haloPx = 2;
        ringAlpha = HALO_ALPHA;
        shadowPx = 3;
        shadowAlpha = SOFT_ALPHA_BUSY;
        weight = 600;
    }
    ringAlpha = Math.min(1, ringAlpha * strength);
    shadowAlpha = Math.min(1, shadowAlpha * strength);
    haloPx = haloPx * ringScale;
    if (strength === 0) {
        haloPx = 0;
        shadowPx = 0;
    }
    if (haloPx === 0)
        ringAlpha = 0;
    // Alpha that reaches the pixels next to a stroke, for the polarity
    // choice: the rim or the shadow's own reach, whichever is firmer.
    var alpha = Math.max(ringAlpha, shadowAlpha * SHADOW_REACH);
    var pick;
    if (stats) {
        pick = polarityFor(stats.mean, s, themeLight, alpha, polarity === "auto" ? undefined : polarity);
    } else {
        var byTheme = themeLight ? s.dark : s.light;
        var forcedSet = polarity === "light" ? s.light : polarity === "dark" ? s.dark : byTheme;
        pick = { set: forcedSet, contrast: 0 };
    }
    var set = pick.set;
    return {
        polarity: set.polarity,
        ink: set.ink,
        inkMuted: set.inkMuted,
        signal: set.signal,
        alert: set.alert,
        halo: set.halo,
        haloAlpha: ringAlpha,
        shadowAlpha: shadowAlpha,
        shadowDy: shadowPx > 0 ? SHADOW_DROP : 0,
        reach: alpha,
        haloPx: haloPx,
        shadowPx: shadowPx,
        weight: weight,
        offAlpha: OFF_SEGMENT_ALPHA,
        style: st,
        known: !!stats,
        contrast: pick.contrast
    };
}

// Parameters of the glyph-halo shader (assets/shaders/clearinkhalo.frag):
// the outline ring and soft shadow radii, and the item padding that keeps
// them inside the shader's texture. Zeros when the tone draws neither.
function effectParams(tone) {
    var reach = Math.max(tone.haloPx, tone.shadowPx + (tone.shadowDy || 0));
    if (reach <= 0)
        return { enabled: false, outlinePx: 0, shadowPx: 0, alpha: 0, shadowAlpha: 0, shadowDy: 0, pad: 0 };
    return {
        enabled: true,
        outlinePx: tone.haloPx,
        shadowPx: tone.shadowPx,
        alpha: tone.haloAlpha,
        shadowAlpha: tone.shadowAlpha || 0,
        shadowDy: tone.shadowDy || 0,
        pad: Math.ceil(reach) + 1
    };
}
