.pragma library

// Bar density (signal-visual-language §4.3): one factor from the screen's
// logical height (already divided by the compositor scale, so 2560x1440@1.5
// and 3840x2160@2 land on 960 and 1080) times the user's multiplier. It
// scales bar thickness, padding, icon and text sizes, but only gently and
// inside legible bounds: primary text never below 12 px, icons 15..18 px,
// segment padding never below 8 px, and bars never thinner than the 24 px
// hit target (the whole bar height is the hit area of every segment).
// Compact screens lose at most 6 % so a 34 px rail is still 32 px on 768p.

var MIN_TEXT = 12;
var MIN_BAR = 24;
var MIN_INNER = 22;
var PT_PER_PX = 0.75; // Qt font.pointSize at the 96 dpi logical grid

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function factor(height, userScale, auto) {
    var user = clamp(userScale > 0 ? userScale : 1, 0.75, 1.5);
    if (!auto || !(height > 0))
        return user;
    var f;
    if (height <= 1080)
        f = 0.94 + 0.06 * (clamp(height, 720, 1080) - 720) / 360;
    else
        f = 1 + 0.10 * Math.min(1, (height - 1080) / 1080);
    return f * user;
}

function thickness(base, f) {
    return Math.max(MIN_BAR, Math.round(base * f));
}

function inner(base, f) {
    return Math.max(MIN_INNER, Math.round(base * f));
}

function icon(f) {
    return clamp(Math.round(16 * f), 15, 18);
}

function text(f) {
    return clamp(Math.round(12 * f), MIN_TEXT, 13);
}

// Eyebrows and meter captions (signal-visual-language §4.1): 11 px caps.
function micro(f) {
    return 11;
}

function clock(f) {
    return Math.max(14, Math.round(16 * f));
}

function segmentPadding(f, vertical) {
    return Math.max(vertical ? 6 : 8, Math.round((vertical ? 8 : 12) * f));
}

function pt(px) {
    return px * PT_PER_PX;
}
