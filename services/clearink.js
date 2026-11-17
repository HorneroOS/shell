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
    ink: "#ECE6DA",
    inkMuted: "#A8ABAD",
    signal: "#FFB650",
    alert: "#F0705A",
    halo: "#0C0F13"
};

var DARK = {
    polarity: "dark",
    ink: "#1B1E22",
    inkMuted: "#4E545B",
    signal: "#8F4B00",
    alert: "#A8341C",
    halo: "#FFFFFF"
};

var STYLES = ["auto", "outline", "shadow", "contrast"];
var DEFAULT_STYLE = "auto";

// §12.1 step 4: peak halo alpha and the deviation above which detailed
// wallpapers get the soft shadow too. The ring is near opaque: a thinner
// alpha lets a vivid wallpaper through and drops the foreground below 4.5:1.
var HALO_ALPHA = 0.96;
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

// Polarity with the larger contrast against the region mean.
function polarityFor(mean, sets) {
    var s = sets || { light: LIGHT, dark: DARK };
    var light = contrast(hexLuminance(s.light.ink), mean);
    var dark = contrast(hexLuminance(s.dark.ink), mean);
    return { set: light >= dark ? s.light : s.dark, contrast: Math.max(light, dark) };
}

// The tone for one region. `stats` may be null (no wallpaper grid: video
// wallpaper, still loading); then polarity follows the theme and both the
// halo and the soft shadow stay on, since nothing is known about detail.
// `style` is one of STYLES, `themeLight` the theme's own mode, `sets` the
// optional setsFrom(clearInk) result.
function toneFor(stats, style, themeLight, sets) {
    var s = sets || { light: LIGHT, dark: DARK };
    var st = normaliseStyle(style);
    var pick;
    var detailed;
    if (stats) {
        pick = polarityFor(stats.mean, s);
        detailed = stats.dev > DETAIL_DEVIATION;
    } else {
        pick = { set: themeLight ? s.dark : s.light, contrast: 0 };
        detailed = true;
    }
    var set = pick.set;
    // Outline radius and soft-shadow radius in logical px. Every style keeps
    // a solid ring around the glyph silhouette: legibility never depends on
    // the wallpaper, only on the foreground (RFC 0001 §5.1).
    var haloPx = 3;
    var shadowPx = 0;
    var weight = 400;
    if (st === "auto") {
        shadowPx = detailed ? 5 : 0;
    } else if (st === "outline") {
        haloPx = 3;
    } else if (st === "shadow") {
        haloPx = 1;
        shadowPx = 4;
    } else if (st === "contrast") {
        haloPx = 3;
        shadowPx = 3;
        weight = 600;
    }
    return {
        polarity: set.polarity,
        ink: set.ink,
        inkMuted: set.inkMuted,
        signal: set.signal,
        alert: set.alert,
        halo: set.halo,
        haloAlpha: HALO_ALPHA,
        haloPx: haloPx,
        shadowPx: shadowPx,
        weight: weight,
        offAlpha: OFF_SEGMENT_ALPHA,
        style: st,
        known: !!stats
    };
}

// Parameters of the glyph-halo shader (assets/shaders/clearinkhalo.frag):
// the outline ring and soft shadow radii, and the item padding that keeps
// them inside the shader's texture. Zeros when the tone draws neither.
function effectParams(tone) {
    var reach = Math.max(tone.haloPx, tone.shadowPx);
    if (reach <= 0)
        return { enabled: false, outlinePx: 0, shadowPx: 0, alpha: 0, pad: 0 };
    return {
        enabled: true,
        outlinePx: tone.haloPx,
        shadowPx: tone.shadowPx,
        alpha: tone.haloAlpha,
        pad: Math.ceil(reach) + 1
    };
}
