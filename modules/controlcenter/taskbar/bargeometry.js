.pragma library

// Pure bar geometry editing for the Bars pane (user directive: every
// debatable size is an end-user control). One bar of `bar.bars` is
// {edge, style, reserve, margin, thickness, density, backdrop, groups};
// the global sizes live in `bar.sizes` and `appearance.{rounding,spacing,
// padding}.scale`. Every function returns a copy, clamps to the same limits
// config/BarConfig.qml enforces, and never touches groups or options.

var EDGES = ["top", "bottom", "left", "right"];
var STYLES = ["attached", "inset", "floating", "islands", "dock"];
var DENSITIES = ["values", "glyphs"];

// Inclusive limits, with the factory default each control resets to when no
// catalogue preset is known. `thickness` is the whole bar body in px.
var LIMITS = {
    thickness: { min: 24, max: 96, step: 2, fallback: 34 },
    margin: { min: 0, max: 24, step: 1, fallback: 6 },
    innerWidth: { min: 22, max: 56, step: 2, fallback: 24 },
    contentScale: { min: 0.75, max: 1.5, step: 0.05, fallback: 1 },
    densityScale: { min: 0.75, max: 1.5, step: 0.05, fallback: 1 },
    roundingScale: { min: 0.5, max: 2, step: 0.1, fallback: 1 },
    spacingScale: { min: 0.75, max: 1.5, step: 0.05, fallback: 1 },
    paddingScale: { min: 0.75, max: 1.5, step: 0.05, fallback: 1 }
};

function clone(v) {
    return JSON.parse(JSON.stringify(v));
}

function toArray(v) {
    if (!v || typeof v !== "object" || typeof v.length !== "number")
        return [];
    return Array.prototype.slice.call(v);
}

function clamp(name, value) {
    var l = LIMITS[name];
    var n = Number(value);
    if (!isFinite(n))
        return l.fallback;
    n = Math.max(l.min, Math.min(l.max, n));
    // Round to the control's step so slider drift never writes 1.0500001.
    return Math.round(Math.round(n / l.step) * l.step * 1000) / 1000;
}

function barIndex(bars, edge) {
    for (var i = 0; i < bars.length; i++)
        if (bars[i] && bars[i].edge === edge)
            return i;
    return -1;
}

// Sets one geometry field of bar `index`. Unknown fields and invalid
// values leave the bars unchanged (copy returned).
function setBarField(bars, index, field, value) {
    var out = clone(toArray(bars));
    if (index < 0 || index >= out.length)
        return out;
    var bar = out[index];
    if (field === "thickness" || field === "margin") {
        bar[field] = clamp(field, value);
    } else if (field === "style") {
        if (STYLES.indexOf(value) < 0)
            return out;
        bar.style = value;
        // The reservation follows the style unless the layout pinned it.
        bar.reserve = value === "attached" || value === "inset" || value === "dock";
    } else if (field === "density") {
        if (DENSITIES.indexOf(value) < 0)
            return out;
        bar.density = value;
    } else if (field === "edge") {
        // One bar per edge: moving onto an occupied edge is refused.
        if (EDGES.indexOf(value) < 0 || barIndex(out, value) >= 0)
            return out;
        bar.edge = value;
    }
    return out;
}

// Geometry of the bar on `edge` in a catalogue preset ({bar:{bars:[...]}}),
// or null.
function presetBar(preset, edge) {
    var bars = preset && preset.bar ? toArray(preset.bar.bars) : [];
    var i = barIndex(bars, edge);
    return i < 0 ? null : bars[i];
}

// Resets thickness, margin, style and density of bar `index` to the
// preset's bar on that edge (or the factory fallbacks when none).
function resetBar(bars, index, preset) {
    var out = clone(toArray(bars));
    if (index < 0 || index >= out.length)
        return out;
    var ref = presetBar(preset, out[index].edge);
    var bar = out[index];
    bar.thickness = ref ? clamp("thickness", ref.thickness) : LIMITS.thickness.fallback;
    bar.margin = ref ? clamp("margin", ref.margin) : LIMITS.margin.fallback;
    if (ref && STYLES.indexOf(ref.style) >= 0) {
        bar.style = ref.style;
        bar.reserve = typeof ref.reserve === "boolean" ? ref.reserve : bar.style !== "floating" && bar.style !== "islands";
    }
    if (ref && DENSITIES.indexOf(ref.density) >= 0)
        bar.density = ref.density;
    return out;
}

// Global values a preset ships, with fallbacks. Keys match LIMITS.
function presetGlobals(preset) {
    var sizes = preset && preset.bar && preset.bar.sizes ? preset.bar.sizes : {};
    var ap = preset && preset.appearance ? preset.appearance : {};
    function scale(group) {
        return ap[group] && typeof ap[group].scale === "number" ? ap[group].scale : 1;
    }
    return {
        innerWidth: clamp("innerWidth", sizes.innerWidth),
        contentScale: clamp("contentScale", sizes.contentScale === undefined ? 1 : sizes.contentScale),
        densityScale: clamp("densityScale", sizes.densityScale === undefined ? 1 : sizes.densityScale),
        roundingScale: clamp("roundingScale", scale("rounding")),
        spacingScale: clamp("spacingScale", scale("spacing")),
        paddingScale: clamp("paddingScale", scale("padding"))
    };
}

// Proportions of the live preview: the bar's cross-axis share of a
// reference screen edge, so the pane can draw it to scale.
function previewRatio(thickness, edge, width, height) {
    var vertical = edge === "left" || edge === "right";
    var across = vertical ? width : height;
    return across > 0 ? Math.min(1, thickness / across) : 0;
}
