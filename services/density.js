.pragma library

// Bar density (signal-visual-language §4): one factor from the screen's
// logical height (already divided by the compositor scale, so 2560x1440@1.5
// and 3840x2160@2 land on 960 and 1080) times the user's multiplier. It
// scales bar thickness, padding, icon and text sizes inside legible bounds:
// text never below 11 px, icons 14..16 px, bars never thinner than the 24 px
// hit target (the whole bar height is the hit area of every segment).

var MIN_TEXT = 11;
var MIN_BAR = 24;
var MIN_INNER = 20;
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
        f = 0.86 + 0.14 * (clamp(height, 720, 1080) - 720) / 360;
    else
        f = 1 + 0.15 * Math.min(1, (height - 1080) / 1080);
    return f * user;
}

function thickness(base, f) {
    return Math.max(MIN_BAR, Math.round(base * f));
}

function inner(base, f) {
    return Math.max(MIN_INNER, Math.round(base * f));
}

function icon(f) {
    return clamp(Math.round(15 * f), 14, 16);
}

function text(f) {
    return clamp(Math.round(12 * f), MIN_TEXT, 12);
}

function micro(f) {
    return MIN_TEXT;
}

function clock(f) {
    return Math.max(13, Math.round(15 * f));
}

function segmentPadding(f, vertical) {
    return Math.max(vertical ? 4 : 6, Math.round((vertical ? 6 : 10) * f));
}

function pt(px) {
    return px * PT_PER_PX;
}
