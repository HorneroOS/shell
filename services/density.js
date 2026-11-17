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

// `cs` is the bar's content scale (`bar.sizes.contentScale`, 0.75..1.5,
// default 1). The chunky Hornero rails raise it so icons and labels grow
// with the wider cells instead of floating in them; the density factor
// still applies on top, so small screens lose a little first.
function contentScale(cs) {
    return clamp(cs > 0 ? cs : 1, 0.75, 1.5);
}

// `is` / `ts` are the item style multipliers (iconScale / textScale).
function icon(f, cs, is) {
    return Math.round(clamp(Math.round(16 * f), 15, 18) * contentScale(cs) * iconScale(is));
}

function text(f, cs, ts) {
    return Math.round(clamp(Math.round(12 * f), MIN_TEXT, 13) * contentScale(cs) * textScale(ts));
}

// Eyebrows and meter captions (signal-visual-language §4.1): 11 px caps,
// 12 px once the content scale reaches 1.15.
function micro(f, cs, ts) {
    return Math.round(11 * Math.sqrt(contentScale(cs)) * textScale(ts));
}

function clock(f, cs, ts) {
    return Math.round(Math.max(14, Math.round(16 * f)) * contentScale(cs) * textScale(ts));
}

function segmentPadding(f, vertical, gap) {
    return Math.max(vertical ? 6 : 8, Math.round((vertical ? 8 : 12) * f * itemSpacing(gap)));
}

function pt(px) {
    return px * PT_PER_PX;
}

// Item style knobs (Bars > Size & shape): each multiplies the value the
// density model derived, so a user choice stays proportional on every screen.
function scaleOf(v, lo, hi) {
    var n = Number(v);
    return clamp(isFinite(n) && n > 0 ? n : 1, lo, hi);
}

function iconScale(v) {
    return scaleOf(v, 0.6, 1.5);
}

function textScale(v) {
    return scaleOf(v, 0.75, 1.5);
}

function itemSpacing(v) {
    return scaleOf(v, 0.5, 2);
}

// Weight of bar values, dates and labels: 300..600 in steps of 50.
function textWeight(v, shift) {
    var n = Number(v);
    var base = clamp(isFinite(n) ? Math.round(n / 50) * 50 : 400, 300, 600);
    var sh = Number(shift);
    return clamp(base + (isFinite(sh) ? sh : 0), 100, 900);
}
