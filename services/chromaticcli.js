.pragma library

// Command-line model of Hornero Chromatic for the shell (RFC 0002 §10,
// contract §5/§6). Pure functions, executed under node by
// tests/test_chromatic_ui_cli.py. The shell previews through the
// `hornero-chromatic` helper (generate only, no files) and applies only
// through `horneroctl appearance chromatic apply`.

var VARIANTS = [
    { id: "balanced", label: "Balanced", description: "Signal Night or Day re-hued to the wallpaper. Quiet surfaces, one confident accent." },
    { id: "vibrant", label: "Vibrant", description: "Stronger accents and lightly tinted chrome. Best on colourful images." },
    { id: "expressive", label: "Expressive", description: "A second accent hue from the image when it has one; more varied status colours." },
    { id: "faithful", label: "Faithful", description: "The image's own dominant colour becomes the accent when it passes the contrast gates." },
    { id: "muted", label: "Muted", description: "Near-neutral chrome with soft accents. Calm; hue is a whisper." },
    { id: "monochrome", label: "Monochrome", description: "Neutral chrome and ink; accents hint at the seed hue. Status colours keep their meaning." },
    { id: "high-contrast", label: "High contrast", description: "Maximum gates (7:1), deeper ground, brighter ink, no glow, no translucency. A look, not the accessibility switch." },
    { id: "neon", label: "Neon", description: "Dark only. Saturated complementary accents and glow. Never chosen automatically." }
];

var MODES = ["auto", "dark", "light"];
var CONTRASTS = ["auto", "standard", "boosted", "maximum"];
var DEPTHS = ["standard", "deep"];
var SOURCES = ["wallpaper", "image", "seed", "house"];
var FOLLOWS = ["off", "auto", "ask"];

function oneOf(list, v, fallback) {
    return list.indexOf(v) >= 0 ? v : fallback;
}

function isHex(h) {
    return /^#[0-9A-Fa-f]{6}$/.test(String(h));
}

function variantInfo(id) {
    for (var i = 0; i < VARIANTS.length; i++) {
        if (VARIANTS[i].id === id)
            return VARIANTS[i];
    }
    return null;
}

// Request from Config.appearance.chromatic plus the live mode, with every
// field clamped to its legal range. Per-mode variant preferences resolve
// here only for an explicit `auto` variant and a known mode.
function normalise(prefs, currentMode) {
    var p = prefs || {};
    var seeds = [];
    var src = Array.isArray(p.seeds) ? p.seeds : [];
    for (var i = 0; i < src.length && seeds.length < 2; i++) {
        if (isHex(src[i]))
            seeds.push(String(src[i]).toUpperCase());
    }
    var chroma = Number(p.chroma);
    var hue = Number(p.hueShift);
    var variant = p.variant === "auto" || variantInfo(p.variant) ? p.variant : "auto";
    return {
        source: oneOf(SOURCES, p.source, "wallpaper"),
        path: typeof p.path === "string" ? p.path : "",
        seeds: seeds,
        variant: variant,
        mode: oneOf(MODES, p.mode, "auto"),
        contrast: oneOf(CONTRASTS, p.contrast, "standard"),
        surfaceDepth: oneOf(DEPTHS, p.surfaceDepth, "standard"),
        chroma: isFinite(chroma) ? Math.max(0.5, Math.min(1.5, chroma)) : 1,
        hueShift: isFinite(hue) ? Math.max(-180, Math.min(180, Math.round(hue))) : 0,
        currentMode: currentMode === "light" ? "light" : "dark"
    };
}

// Variant for the mode: an explicit variant wins, then the per-mode
// preference, else "auto" (the engine infers).
function effectiveVariant(req, perMode) {
    if (req.variant !== "auto")
        return req.variant;
    var mode = req.mode === "auto" ? req.currentMode : req.mode;
    var pref = perMode && perMode[mode] && perMode[mode].variant;
    return pref && variantInfo(pref) ? pref : "auto";
}

function _flags(req, variant) {
    var f = ["--variant", variant, "--mode", req.mode, "--contrast", req.contrast,
        "--depth", req.surfaceDepth, "--chroma", Number(req.chroma).toFixed(2),
        "--hue-shift", String(req.hueShift)];
    return f;
}

// Arguments for `hornero-chromatic generate` (no files written).
// `wallpaper` is the current wallpaper path for the wallpaper/house
// sources. Returns null when the request has no usable source.
function helperArgs(req, wallpaper, perMode) {
    var variant = effectiveVariant(req, perMode);
    var args = ["generate"];
    if (req.source === "wallpaper") {
        if (!wallpaper)
            return null;
        args.push("--source", wallpaper);
    } else if (req.source === "image") {
        if (!req.path)
            return null;
        args.push("--source", req.path);
    } else if (req.source === "seed") {
        if (req.seeds.length === 0)
            return null;
        for (var i = 0; i < req.seeds.length; i++)
            args.push("--seed", req.seeds[i]);
    } else {
        args.push("--house");
        if (wallpaper)
            args.push("--wallpaper", wallpaper);
    }
    args = args.concat(_flags(req, variant));
    args.push("--current-mode", req.currentMode);
    return args;
}

// Source arguments shared by horneroctl verbs.
function ctlRequestArgs(req, perMode) {
    var args = [];
    if (req.source === "image")
        args.push("--source", "image:" + req.path);
    else
        args.push("--source", req.source);
    if (req.source === "seed") {
        for (var i = 0; i < req.seeds.length; i++)
            args.push("--seed", req.seeds[i]);
    }
    return args.concat(_flags(req, effectiveVariant(req, perMode)));
}

// `horneroctl appearance chromatic apply …` (--json --yes last, like every
// other mutating verb the shell runs).
function applyArgs(req, perMode, persist) {
    var args = ["horneroctl", "appearance", "chromatic", "apply"].concat(ctlRequestArgs(req, perMode));
    if (persist === false)
        args.push("--no-persist");
    args.push("--json", "--yes");
    return args;
}

function saveArgs(id, name) {
    return ["horneroctl", "appearance", "chromatic", "save", "--id", id, "--name", name, "--json", "--yes"];
}

function exportArgs(path) {
    return ["horneroctl", "appearance", "chromatic", "export", "--output", path, "--json"];
}

function importArgs(path, id) {
    var a = ["horneroctl", "appearance", "chromatic", "import", path];
    if (id)
        a.push("--id", id);
    a.push("--json", "--yes");
    return a;
}

function rollbackArgs() {
    return ["horneroctl", "appearance", "chromatic", "rollback", "--steps", "1", "--json", "--yes"];
}

function offArgs() {
    return ["horneroctl", "appearance", "chromatic", "off", "--json", "--yes"];
}

function followArgs() {
    return ["horneroctl", "appearance", "chromatic", "follow", "--json", "--yes"];
}

// Kebab-case theme id from a display name; "" when nothing usable.
function slug(name) {
    var s = String(name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (!s || s === "hornero-chromatic")
        return s ? s + "-1" : "";
    return s.substr(0, 48);
}

// Honest, user-facing state for a failed helper run (exit code per
// contract §5.1) or a missing helper.
function describeFailure(exitCode, stderr, helperMissing, isVideo) {
    var tail = String(stderr || "").trim().split("\n").slice(-1)[0] || "";
    if (helperMissing)
        return { code: "engine-missing", title: "Chromatic engine not installed", detail: "The hornero-chromatic helper was not found. It ships with hornero-shell; update or reinstall it to use dynamic colour. Your current theme is unchanged." };
    if (exitCode === 3) {
        if (isVideo)
            return { code: "video-needs-ffmpeg", title: "Cannot read this video", detail: "A video wallpaper needs ffmpeg to extract a frame. Install ffmpeg or pick a still image. " + tail };
        return { code: "source-unreadable", title: "Cannot read this image", detail: "The file is missing, empty, truncated or in an unsupported format. " + tail };
    }
    if (exitCode === 4)
        return { code: "gates-unreachable", title: "No palette passes the contrast gates", detail: "Try another variant or a higher contrast level. " + tail };
    if (exitCode === 2)
        return { code: "usage", title: "Invalid request", detail: tail };
    return { code: "internal", title: "Chromatic failed", detail: tail || ("exit " + exitCode) };
}

var VIDEO_EXT = ["mp4", "webm", "mkv", "mov", "avi", "m4v", "gif"];

function isVideoPath(path) {
    var m = /\.([A-Za-z0-9]+)$/.exec(String(path || ""));
    return !!m && VIDEO_EXT.indexOf(m[1].toLowerCase()) >= 0;
}

// Request object for the in-process engine (Hornero.Chromatic
// ChromaticEngine.generate): the RFC §8.3 keys plus `path` and
// `currentMode`. Null when the request has no usable source.
function engineRequest(req, wallpaper, perMode) {
    var variant = effectiveVariant(req, perMode);
    var path = "";
    if (req.source === "wallpaper") {
        if (!wallpaper)
            return null;
        path = wallpaper;
    } else if (req.source === "image") {
        if (!req.path)
            return null;
        path = req.path;
    } else if (req.source === "seed") {
        if (req.seeds.length === 0)
            return null;
    } else if (wallpaper) {
        path = wallpaper;
    }
    return {
        source: req.source,
        path: path,
        seeds: req.seeds,
        variant: variant,
        mode: req.mode,
        contrast: req.contrast,
        surfaceDepth: req.surfaceDepth,
        chroma: req.chroma,
        hueShift: req.hueShift,
        currentMode: req.currentMode
    };
}

// In-process engine failure code to the helper exit code it stands for.
function engineFailureExit(code) {
    return code === "source-unreadable" ? 3 : code === "usage" ? 2 : 5;
}

// Parse the helper's `generate` document (JSON text).
function parseGenerate(text) {
    var doc = null;
    try {
        doc = JSON.parse(text);
    } catch (e) {
        return { ok: false, error: "helper printed invalid JSON" };
    }
    return parseDocument(doc);
}

// Normalise a generate document (helper stdout or in-process result).
// Returns {ok, result} or {ok: false, error}. Unknown fields are ignored;
// a missing or incomplete scheme is an error (nothing is ever previewed
// from a partial document).
function parseDocument(doc) {
    if (!doc || doc.schemaVersion !== 1 || !doc.scheme || !doc.scheme.palette)
        return { ok: false, error: "helper document has no scheme" };
    var rows = [];
    var src = (doc.gates && Array.isArray(doc.gates.rows)) ? doc.gates.rows : [];
    for (var i = 0; i < src.length; i++) {
        var r = src[i];
        rows.push({ label: String(r[0]), ratio: Number(r[1]), min: Number(r[2]), pass: Number(r[1]) >= Number(r[2]) });
    }
    return {
        ok: true,
        result: {
            scheme: doc.scheme,
            analysis: doc.analysis || null,
            inference: doc.inference || null,
            gates: { level: doc.gates ? doc.gates.level : "", passed: !!(doc.gates && doc.gates.passed), rows: rows },
            adjustments: Array.isArray(doc.adjustments) ? doc.adjustments : [],
            fingerprint: String(doc.fingerprint || ""),
            request: doc.request || null
        }
    };
}

// Readout of the smart inference: one line per decision, with whether the
// user's own setting overrides it. Every decision stays overridable.
function inferenceRows(inference, req) {
    if (!inference)
        return [];
    var rows = [];
    function row(key, label, inferred, chosen) {
        rows.push({ key: key, label: label, inferred: String(inferred || ""), chosen: String(chosen), overridden: chosen !== "auto" && String(inferred || "") !== "" && chosen !== inferred });
    }
    row("mode", "Mode", inference.mode, req.mode);
    row("variant", "Variant", inference.variant, req.variant);
    row("contrast", "Contrast", inference.contrast, req.contrast);
    return rows;
}
