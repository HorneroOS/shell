.pragma library

// Companion reactions: the pure policy that decides whether a REAL
// event (a notification arrived, the battery is low, a build finished
// ...) makes Javi react, and how. No QML, no timers, no I/O: every
// function takes its inputs explicitly so the whole policy runs under
// node in tests/test_companion_reactions.py.
//
// Principles (docs/COMPANION.md "Reactions"):
// - Only real events. Native kinds are emitted by the shell service that
//   observed the event; external kinds (build, download, device, task)
//   come from IPC or a PluginKit extension through a governed allowlist.
// - Never intrusive: per-kind cooldown, a global rate limit, and the
//   active Experience mode and quiet hours can only make Javi quieter.
// - Always user-owned: every kind can be switched off and every mode has
//   its own behaviour level.

// priority: 1 ambient, 2 notable, 3 important (survives "quiet").
// external: may be raised through IPC / PluginKit (never the native-only
// kinds, so an extension cannot fake a battery warning).
var KINDS = {
    "notification": { label: "New notification", priority: 1, anim: "look", bubble: "", cooldownMs: 4000, external: false },
    "battery.low": { label: "Battery low", priority: 2, anim: "worry", bubble: "Battery is getting low.", cooldownMs: 120000, external: false },
    "battery.critical": { label: "Battery critical", priority: 3, anim: "worry", bubble: "Battery is critical. Plug in soon.", cooldownMs: 60000, external: false },
    "charger.plugged": { label: "Charger connected", priority: 1, anim: "approve", bubble: "", cooldownMs: 15000, external: false },
    "charger.unplugged": { label: "Charger removed", priority: 1, anim: "look", bubble: "", cooldownMs: 15000, external: false },
    "mode.changed": { label: "Experience mode changed", priority: 1, anim: "blink", bubble: "", cooldownMs: 5000, external: false },
    "build.done": { label: "Build finished", priority: 2, anim: "celebrate", bubble: "Build finished.", cooldownMs: 10000, external: true },
    "build.failed": { label: "Build failed", priority: 2, anim: "worry", bubble: "The build failed.", cooldownMs: 10000, external: true },
    "download.done": { label: "Download finished", priority: 1, anim: "approve", bubble: "Download finished.", cooldownMs: 8000, external: true },
    "device.connected": { label: "Device connected", priority: 1, anim: "look", bubble: "", cooldownMs: 8000, external: true },
    "device.disconnected": { label: "Device disconnected", priority: 1, anim: "look", bubble: "", cooldownMs: 8000, external: true },
    "task.done": { label: "Task finished", priority: 1, anim: "approve", bubble: "", cooldownMs: 8000, external: true },
    "attention": { label: "Needs your attention", priority: 2, anim: "hop", bubble: "", cooldownMs: 20000, external: true }
};

var KIND_IDS = Object.keys(KINDS);

// Behaviour per Experience mode: full (every enabled kind), quiet (only
// important kinds, animation only, no bubble), silent (no reactions).
var LEVELS = ["full", "quiet", "silent"];
var MODE_IDS = ["focus", "everyday", "signal", "gaming", "studio"];
var DEFAULT_MODE_BEHAVIOUR = { focus: "quiet", everyday: "full", signal: "full", gaming: "silent", studio: "quiet" };

var GLOBAL_WINDOW_MS = 300000;
var GLOBAL_MAX = 6;
var SOURCE_WINDOW_MS = 60000;
var SOURCE_MAX = 3;
var TEXT_MAX = 80;
var BUBBLE_MS = 5000;

function defaults() {
    return {
        enabled: true,
        bubbles: true,
        kindsOff: [],
        modeBehaviour: { focus: "quiet", everyday: "full", signal: "full", gaming: "silent", studio: "quiet" },
        quietHours: { enabled: false, start: "22:00", end: "07:00" },
        mutedSources: []
    };
}

// Per-mode look: the companion can be hidden, resized (multiplier on the
// global size) or re-skinned while a given Experience mode is active.
// skin "" means "use the global skin".
function defaultModeLook() {
    var out = {};
    for (var i = 0; i < MODE_IDS.length; i++)
        out[MODE_IDS[i]] = { visible: true, size: 1.0, skin: "" };
    return out;
}

function sanitizeModeLook(raw) {
    var out = defaultModeLook();
    var o = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    for (var i = 0; i < MODE_IDS.length; i++) {
        var src = o[MODE_IDS[i]];
        if (!src || typeof src !== "object")
            continue;
        if (typeof src.visible === "boolean")
            out[MODE_IDS[i]].visible = src.visible;
        if (typeof src.size === "number" && isFinite(src.size))
            out[MODE_IDS[i]].size = Math.max(0.5, Math.min(2.0, Math.round(src.size * 20) / 20));
        if (typeof src.skin === "string" && /^[a-z0-9-]{0,32}$/.test(src.skin))
            out[MODE_IDS[i]].skin = src.skin;
    }
    return out;
}

function emptyHistory() {
    return { lastByKind: {}, recent: [], bySource: {} };
}

// "HH:MM" -> minutes since midnight, or -1 when invalid.
function parseClock(text) {
    var m = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(String(text === undefined || text === null ? "" : text).trim());
    return m ? parseInt(m[1], 10) * 60 + parseInt(m[2], 10) : -1;
}

function formatClock(minutes) {
    var m = Math.max(0, Math.min(1439, Math.round(minutes)));
    var h = Math.floor(m / 60);
    var mm = m % 60;
    return (h < 10 ? "0" : "") + h + ":" + (mm < 10 ? "0" : "") + mm;
}

// True when `minute` falls inside [start, end), wrapping past midnight.
// start === end means "never" (an empty window), not "always".
function inQuietHours(quiet, minute) {
    if (!quiet || !quiet.enabled)
        return false;
    var s = parseClock(quiet.start);
    var e = parseClock(quiet.end);
    if (s < 0 || e < 0 || s === e)
        return false;
    return s < e ? (minute >= s && minute < e) : (minute >= s || minute < e);
}

// Validates a persisted/settings object back to a complete, safe one.
function sanitizeSettings(raw) {
    var d = defaults();
    var o = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    if (typeof o.enabled === "boolean")
        d.enabled = o.enabled;
    if (typeof o.bubbles === "boolean")
        d.bubbles = o.bubbles;
    if (Array.isArray(o.kindsOff))
        d.kindsOff = o.kindsOff.filter(function (k, i, a) { return KINDS[k] !== undefined && a.indexOf(k) === i; });
    if (o.modeBehaviour && typeof o.modeBehaviour === "object") {
        for (var i = 0; i < MODE_IDS.length; i++) {
            var lv = o.modeBehaviour[MODE_IDS[i]];
            if (LEVELS.indexOf(lv) >= 0)
                d.modeBehaviour[MODE_IDS[i]] = lv;
        }
    }
    if (o.quietHours && typeof o.quietHours === "object") {
        if (typeof o.quietHours.enabled === "boolean")
            d.quietHours.enabled = o.quietHours.enabled;
        if (parseClock(o.quietHours.start) >= 0)
            d.quietHours.start = formatClock(parseClock(o.quietHours.start));
        if (parseClock(o.quietHours.end) >= 0)
            d.quietHours.end = formatClock(parseClock(o.quietHours.end));
    }
    if (Array.isArray(o.mutedSources))
        d.mutedSources = o.mutedSources.filter(function (s, i, a) { return typeof s === "string" && /^(shell|ipc|plugin:[a-z0-9][a-z0-9._-]{0,63})$/.test(s) && a.indexOf(s) === i; }).slice(0, 64);
    return d;
}

// External text is untrusted: plain text only, one line, bounded.
function sanitizeText(text) {
    if (text === undefined || text === null)
        return "";
    var t = String(text).replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2066-\u2069]/g, " ").replace(/\s+/g, " ").trim();
    return t.length > TEXT_MAX ? t.slice(0, TEXT_MAX - 1) + "…" : t;
}

// Source ids: "shell" for native kinds, "ipc", or "plugin:<id>".
function sourceKey(source) {
    var s = String(source === undefined || source === null ? "" : source).toLowerCase();
    if (s === "shell" || s === "ipc")
        return s;
    var m = /^plugin:([a-z0-9][a-z0-9._-]{0,63})$/.exec(s);
    return m ? "plugin:" + m[1] : "";
}

function effectiveLevel(settings, mode, minute) {
    var level = settings.modeBehaviour[mode] || DEFAULT_MODE_BEHAVIOUR[mode] || "full";
    if (inQuietHours(settings.quietHours, minute) && level === "full")
        level = "quiet";
    return level;
}

// input: { settings, kind, source, text, mode, nowMs, minute, history,
//          hasAnimation(name) }
// -> { ok: true, kind, anim, bubble, bubbleMs, priority, source }
//  | { ok: false, reason }
function decide(input) {
    var s = sanitizeSettings(input.settings);
    var kind = String(input.kind === undefined || input.kind === null ? "" : input.kind);
    var def = KINDS[kind];
    if (def === undefined)
        return { ok: false, reason: "unknown-kind" };
    var source = sourceKey(input.source);
    if (source === "")
        return { ok: false, reason: "invalid-source" };
    if (source !== "shell" && !def.external)
        return { ok: false, reason: "native-only" };
    if (!s.enabled)
        return { ok: false, reason: "disabled" };
    if (s.kindsOff.indexOf(kind) >= 0)
        return { ok: false, reason: "kind-off" };
    if (s.mutedSources.indexOf(source) >= 0)
        return { ok: false, reason: "source-muted" };
    var level = effectiveLevel(s, input.mode, input.minute);
    if (level === "silent")
        return { ok: false, reason: "mode-silent" };
    if (level === "quiet" && def.priority < 3)
        return { ok: false, reason: "mode-quiet" };

    var now = input.nowMs;
    var h = input.history || emptyHistory();
    var last = h.lastByKind[kind];
    if (last !== undefined && now - last < def.cooldownMs)
        return { ok: false, reason: "cooldown" };
    if (def.priority < 3) {
        var live = (h.recent || []).filter(function (t) { return now - t < GLOBAL_WINDOW_MS; });
        if (live.length >= GLOBAL_MAX)
            return { ok: false, reason: "rate-limit" };
    }
    if (source !== "shell") {
        var theirs = ((h.bySource || {})[source] || []).filter(function (t) { return now - t < SOURCE_WINDOW_MS; });
        if (theirs.length >= SOURCE_MAX)
            return { ok: false, reason: "source-rate-limit" };
    }

    var anim = def.anim;
    if (typeof input.hasAnimation === "function" && !input.hasAnimation(anim))
        anim = "";
    var bubble = "";
    var isCustom = false;
    if (level === "full" && s.bubbles) {
        var custom = source === "shell" ? "" : sanitizeText(input.text);
        isCustom = custom !== "";
        bubble = isCustom ? custom : def.bubble;
    }
    if (anim === "" && bubble === "")
        return { ok: false, reason: "nothing-to-show" };
    return { ok: true, kind: kind, anim: anim, bubble: bubble, custom: isCustom, bubbleMs: BUBBLE_MS, priority: def.priority, source: source };
}

// Returns a new history with an accepted reaction recorded (old entries
// pruned so the structure stays bounded).
function record(history, kind, source, nowMs) {
    var h = history || emptyHistory();
    var out = { lastByKind: {}, recent: [], bySource: {} };
    Object.keys(h.lastByKind || {}).forEach(function (k) { out.lastByKind[k] = h.lastByKind[k]; });
    out.lastByKind[kind] = nowMs;
    out.recent = (h.recent || []).filter(function (t) { return nowMs - t < GLOBAL_WINDOW_MS; }).concat([nowMs]);
    Object.keys(h.bySource || {}).forEach(function (k) {
        var kept = h.bySource[k].filter(function (t) { return nowMs - t < SOURCE_WINDOW_MS; });
        if (kept.length > 0)
            out.bySource[k] = kept;
    });
    if (source !== "shell")
        out.bySource[source] = (out.bySource[source] || []).concat([nowMs]);
    return out;
}

function catalog() {
    return KIND_IDS.map(function (id) {
        return { id: id, label: KINDS[id].label, priority: KINDS[id].priority, external: KINDS[id].external };
    });
}
