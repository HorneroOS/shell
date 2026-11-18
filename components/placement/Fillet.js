.pragma library

// Machined fillets (Signal visual language §7.1): where an attached drawer
// or popout meets the bar or the frame, a small concave quarter arc lets
// the sheet grow out of the bezel instead of sitting on it. Pure policy,
// shared by the drawers (modules/drawers/Backgrounds.qml through BarSet)
// and the bar popouts (SurfaceFrame); tested by tests/test_fillets.py.

var MAX = 16;

// The user setting (border.fillet) clamped to its range; 0 = flush.
function setting(value) {
    var v = Number(value);
    if (!isFinite(v))
        return 0;
    return Math.max(0, Math.min(MAX, v));
}

// Radius at one screen edge. `open` is true when the bar on that edge
// floats or is clear (the sheet keeps a breathing gap: SVL §7.1 floating
// rule), `framed` when the frame is painted, `hasBar` when a bar sits on
// that edge. A bare screen edge (no frame, no bar, e.g. the sides of
// Cockpit Clear) has nothing to grow out of.
function radius(value, open, framed, hasBar) {
    var f = setting(value);
    if (f <= 0 || open)
        return 0;
    return framed || hasBar ? f : 0;
}

// Offset of the junction outline from the anchor line into the sheet, in
// px: the frame paints its edge line inside the cutout (Border.qml, High
// Contrast never thinner than 2 px); an attached bar without a frame
// paints its hairline on its own inner pixel (Bar.qml).
function rule(framed, hasBar, highContrast, edgeWidth) {
    if (framed) {
        var w = Math.max(0, Number(edgeWidth) || 0);
        return (highContrast ? Math.max(2, w) : w) / 2;
    }
    return hasBar ? -0.5 : 0;
}

// The radius actually drawn: never more than the sheet's depth leaves
// after its free corner and the outline offset, so a fillet grows with an
// opening sheet instead of eating its side.
function fit(value, depth, corner, ruleOffset) {
    if (!(value > 0))
        return 0;
    return Math.max(0, Math.min(value, depth - corner - Math.max(0, ruleOffset)));
}
