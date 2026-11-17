.pragma library

// Experience modes (RFC 0001 §5a, Signal Visual Language §13).
//
// Pure data + functions so the profiles, customisation rules, state
// parsing and legacy migration run under node in tests/test_experience.py.
// services/Experience.qml is the only QML consumer; nothing here touches
// the system.
//
// A mode is a declarative behaviour profile. It composes with the
// edition (installed capabilities), the layout preset and the theme; it
// never replaces any of them.

var SCHEMA_VERSION = 1;

var MODE_IDS = ["focus", "everyday", "signal", "gaming", "studio"];
var DEFAULT_MODE = "everyday";

// Factory reset target (RFC §5a): everyday + Cockpit + Signal Night.
var FACTORY_LAYOUT = "cockpit";
var FACTORY_THEME = "hornero-signal-night";

var MOTION_LEVELS = ["full", "standard", "reduced", "off"];
var DENSITIES = ["icons", "values", "labels"];
var DESKTOP_WIDGETS = ["none", "user", "instruments"];
var POWER_HINTS = ["", "performance", "power-saver"];
var STATE_SOURCES = ["user", "auto", "cli", "reset", "migration"];
// `horneroctl studio mode audio` ids (HorneroOS/hornero studio_mode.v).
var STUDIO_AUDIO_MODES = ["balanced", "low-latency", "advanced"];

// Every customisable field, flat dotted keys, with its validator. A user
// override is stored under shell.json experience.modes.<mode>.<key> and is
// never discarded by a mode switch, a shell restart or a factory reset of
// another mode.
var FIELDS = {
    "motion": { type: "enum", values: MOTION_LEVELS },
    "density": { type: "enum", values: DENSITIES },
    "glow": { type: "bool" },
    "scanlines": { type: "bool" },
    "telemetry.rateHz": { type: "number", min: 0.2, max: 4 },
    "telemetry.pauseWhenHidden": { type: "bool" },
    "desktopWidgets": { type: "enum", values: DESKTOP_WIDGETS },
    "notifications.hold": { type: "bool" },
    "notifications.suppressFullscreen": { type: "bool" },
    "layout.preset": { type: "string" },
    "layout.apply": { type: "bool" },
    "idle.inhibitFullscreen": { type: "bool" },
    "power.suggest": { type: "enum", values: POWER_HINTS },
    "hooks.hyprlandTuning": { type: "bool" },
    "hooks.studioAudio": { type: "bool" }
};

// Guardrails the RFC makes non-negotiable: glow is off in Focus and
// Gaming; Gaming never animates. A locked field ignores overrides.
var LOCKED = {
    "focus": { "glow": false, "scanlines": false },
    "gaming": { "glow": false, "scanlines": false, "motion": "off" }
};

function _profile(id, label, glyph, description, fields) {
    return { id: id, label: label, glyph: glyph, description: description, fields: fields };
}

var FACTORY = {
    "focus": _profile("focus", "Focus", "circle-dot",
        "Maximum space, quiet motion, notifications held.", {
            "motion": "reduced",
            "density": "icons",
            "glow": false,
            "scanlines": false,
            "telemetry.rateHz": 1,
            "telemetry.pauseWhenHidden": true,
            "desktopWidgets": "none",
            "notifications.hold": true,
            "notifications.suppressFullscreen": true,
            "layout.preset": "minimal-top",
            "layout.apply": false,
            "idle.inhibitFullscreen": false,
            "power.suggest": "",
            "hooks.hyprlandTuning": false,
            "hooks.studioAudio": false
        }),
    "everyday": _profile("everyday", "Everyday", "layout-dashboard",
        "Balanced default: Cockpit, standard motion, values on the bar.", {
            "motion": "standard",
            "density": "values",
            "glow": false,
            "scanlines": false,
            "telemetry.rateHz": 1,
            "telemetry.pauseWhenHidden": false,
            "desktopWidgets": "user",
            "notifications.hold": false,
            "notifications.suppressFullscreen": false,
            "layout.preset": "cockpit",
            "layout.apply": false,
            "idle.inhibitFullscreen": false,
            "power.suggest": "",
            "hooks.hyprlandTuning": false,
            "hooks.studioAudio": false
        }),
    "signal": _profile("signal", "Signal", "wave-sine",
        "Immersive: desktop instruments, labelled telemetry at 2 Hz, glow and scanlines.", {
            "motion": "full",
            "density": "labels",
            "glow": true,
            "scanlines": true,
            "telemetry.rateHz": 2,
            "telemetry.pauseWhenHidden": false,
            "desktopWidgets": "instruments",
            "notifications.hold": false,
            "notifications.suppressFullscreen": false,
            "layout.preset": "cockpit",
            "layout.apply": false,
            "idle.inhibitFullscreen": false,
            "power.suggest": "",
            "hooks.hyprlandTuning": false,
            "hooks.studioAudio": false
        }),
    "gaming": _profile("gaming", "Gaming", "device-gamepad-2",
        "Out of the way: no motion or glow, notifications queued, polling paused under fullscreen.", {
            "motion": "off",
            "density": "icons",
            "glow": false,
            "scanlines": false,
            "telemetry.rateHz": 1,
            "telemetry.pauseWhenHidden": true,
            "desktopWidgets": "none",
            "notifications.hold": true,
            "notifications.suppressFullscreen": true,
            "layout.preset": "gaming",
            "layout.apply": false,
            "idle.inhibitFullscreen": true,
            "power.suggest": "performance",
            "hooks.hyprlandTuning": true,
            "hooks.studioAudio": false
        }),
    "studio": _profile("studio", "Studio", "wave-square",
        "Audio first: stable canvas, standard motion, no glow, low-latency audio hint.", {
            "motion": "standard",
            "density": "values",
            "glow": false,
            "scanlines": false,
            "telemetry.rateHz": 1,
            "telemetry.pauseWhenHidden": false,
            "desktopWidgets": "user",
            "notifications.hold": false,
            "notifications.suppressFullscreen": true,
            "layout.preset": "studio",
            "layout.apply": false,
            "idle.inhibitFullscreen": false,
            "power.suggest": "",
            "hooks.hyprlandTuning": false,
            "hooks.studioAudio": false
        })
};

function isMode(id) {
    return typeof id === "string" && MODE_IDS.indexOf(id) >= 0;
}

function isLocked(mode, key) {
    var l = LOCKED[mode];
    return !!l && Object.prototype.hasOwnProperty.call(l, key);
}

// Returns the normalised value, or undefined when it is not acceptable.
function validateField(key, value) {
    var spec = FIELDS[key];
    if (!spec)
        return undefined;
    if (spec.type === "bool")
        return typeof value === "boolean" ? value : undefined;
    if (spec.type === "enum")
        return spec.values.indexOf(value) >= 0 ? value : undefined;
    if (spec.type === "number") {
        if (typeof value !== "number" || !isFinite(value))
            return undefined;
        return Math.max(spec.min, Math.min(spec.max, value));
    }
    if (spec.type === "string")
        return typeof value === "string" && /^[a-z0-9][a-z0-9-]{0,63}$/.test(value) ? value : undefined;
    return undefined;
}

// Presets that were genuinely retired, mapped to the survivor a persisted
// selection moves to while overrides are sanitised. Floating Island and
// Productivity were briefly listed here (shell#484) and are supported
// presets again, so a saved selection of either is kept as is. Add an id
// only when its preset file is deleted for good.
var RETIRED_PRESETS = {};

function migratePreset(id) {
    return typeof id === "string" && Object.prototype.hasOwnProperty.call(RETIRED_PRESETS, id) ? RETIRED_PRESETS[id] : id;
}

// Drops unknown modes, unknown keys, invalid values, locked fields and
// values equal to the factory profile. Never mutates its input.
function sanitizeOverrides(raw) {
    var out = {};
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return out;
    for (var i = 0; i < MODE_IDS.length; i++) {
        var mode = MODE_IDS[i];
        var src = raw[mode];
        if (!src || typeof src !== "object" || Array.isArray(src))
            continue;
        var clean = {};
        var any = false;
        for (var key in src) {
            if (!Object.prototype.hasOwnProperty.call(src, key) || isLocked(mode, key))
                continue;
            var v = validateField(key, key === "layout.preset" ? migratePreset(src[key]) : src[key]);
            if (v === undefined || v === FACTORY[mode].fields[key])
                continue;
            clean[key] = v;
            any = true;
        }
        if (any)
            out[mode] = clean;
    }
    return out;
}

// Effective profile: factory fields, then valid user overrides, then the
// locked guardrails. `customised` lists the keys a user changed.
function resolve(mode, overrides) {
    if (!isMode(mode))
        mode = DEFAULT_MODE;
    var base = FACTORY[mode];
    var clean = sanitizeOverrides(overrides)[mode] || {};
    var fields = {};
    for (var key in base.fields)
        fields[key] = base.fields[key];
    var customised = [];
    for (var k in clean) {
        fields[k] = clean[k];
        customised.push(k);
    }
    var locked = LOCKED[mode] || {};
    for (var lk in locked)
        fields[lk] = locked[lk];
    customised.sort();
    return {
        id: mode,
        label: base.label,
        glyph: base.glyph,
        description: base.description,
        fields: fields,
        customised: customised,
        locked: Object.keys(locked).sort()
    };
}

// Writes one override (or removes it when value is null / equals factory).
// Returns { ok, overrides, error }. The other modes are untouched.
function setOverride(overrides, mode, key, value) {
    if (!isMode(mode))
        return { ok: false, overrides: overrides, error: "unknown mode: " + mode };
    if (!FIELDS[key])
        return { ok: false, overrides: overrides, error: "unknown field: " + key };
    if (isLocked(mode, key))
        return { ok: false, overrides: overrides, error: key + " is fixed in " + mode + " mode" };
    var next = sanitizeOverrides(overrides);
    var bucket = next[mode] || {};
    if (value === null || value === undefined || value === FACTORY[mode].fields[key]) {
        delete bucket[key];
    } else {
        var v = validateField(key, value);
        if (v === undefined)
            return { ok: false, overrides: overrides, error: "invalid value for " + key };
        bucket[key] = v;
    }
    if (Object.keys(bucket).length > 0)
        next[mode] = bucket;
    else
        delete next[mode];
    return { ok: true, overrides: next, error: "" };
}

function clearOverrides(overrides, mode) {
    var next = sanitizeOverrides(overrides);
    delete next[mode];
    return next;
}

// ---- Runtime policy -----------------------------------------------------
//
// What a mode means while a window covers the output. This is the single
// definition: services/Experience.qml binds its public properties to it and
// tests/test_experience.py exercises it under node, so the Gaming guarantees
// (queued notifications, paused polling, no desktop layer, idle inhibit)
// are checked as behaviour, not as source text.

// Hyprland reports a window's fullscreen state as a bit set: 1 maximised,
// 2 fullscreen, 3 both. Anything with the fullscreen bit covers the output.
function isFullscreenState(value) {
    return typeof value === "number" && isFinite(value) && (value & 2) === 2;
}

// fields: an effective profile's `fields`; ctx: { mode, fullscreen }.
function policy(fields, ctx) {
    var fs = !!(ctx && ctx.fullscreen);
    var gaming = !!(ctx && ctx.mode === "gaming");
    return {
        holdPopups: !!fields["notifications.hold"] || (!!fields["notifications.suppressFullscreen"] && fs),
        telemetryPaused: !!fields["telemetry.pauseWhenHidden"] && fs,
        desktopWidgetsVisible: fields["desktopWidgets"] !== "none" && !(gaming && fs),
        idleInhibit: !!fields["idle.inhibitFullscreen"] && fs
    };
}

// Notification routing under the hold policy. Critical notifications are
// never held (a battery-critical or security prompt must reach the person);
// Do Not Disturb files everything silently; otherwise a held notification
// is filed without a popup and counted so leaving the mode can report it.
function notificationDisposition(hold, critical, dnd) {
    var held = !critical && !dnd && !!hold;
    return {
        held: held,
        popup: !!critical || (!dnd && !held)
    };
}

// ---- Persisted state ($XDG_STATE_HOME/hornero/experience.json) --------

function defaultState() {
    return {
        schemaVersion: SCHEMA_VERSION,
        mode: DEFAULT_MODE,
        previous: DEFAULT_MODE,
        source: "user",
        auto: false,
        changedAt: "",
        studioAudioRestore: ""
    };
}

// Fails closed: anything that is not a valid schema-1 object yields null
// so the caller keeps its current mode instead of a partial state.
// horneroctl may write the minimal form {"schemaVersion":1,"mode":"focus"}.
function parseState(text) {
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!data || typeof data !== "object" || Array.isArray(data))
        return null;
    if (data.schemaVersion !== SCHEMA_VERSION || !isMode(data.mode))
        return null;
    var st = defaultState();
    st.mode = data.mode;
    st.previous = isMode(data.previous) ? data.previous : data.mode;
    st.source = STATE_SOURCES.indexOf(data.source) >= 0 ? data.source : "cli";
    st.auto = data.auto === true;
    st.changedAt = typeof data.changedAt === "string" ? data.changedAt : "";
    st.studioAudioRestore = STUDIO_AUDIO_MODES.indexOf(data.studioAudioRestore) >= 0 ? data.studioAudioRestore : "";
    return st;
}

function serializeState(st) {
    return JSON.stringify({
        schemaVersion: SCHEMA_VERSION,
        mode: st.mode,
        previous: st.previous,
        source: st.source,
        auto: st.auto === true,
        changedAt: st.changedAt || "",
        studioAudioRestore: st.studioAudioRestore || ""
    }, null, 2) + "\n";
}

// Pure transition. `auto` marks a switch made by automatic rules so the
// UI can offer a one-action revert and the rule knows what to undo.
function transition(st, mode, source, nowIso) {
    if (!isMode(mode))
        return { ok: false, state: st, error: "unknown mode: " + mode };
    var src = STATE_SOURCES.indexOf(source) >= 0 ? source : "user";
    var next = {
        schemaVersion: SCHEMA_VERSION,
        mode: mode,
        previous: st.mode === mode ? st.previous : st.mode,
        source: src,
        auto: src === "auto",
        changedAt: nowIso || "",
        studioAudioRestore: st.studioAudioRestore || ""
    };
    return { ok: true, state: next, changed: st.mode !== mode, error: "" };
}

// ---- One-shot migration of pre-Experience settings -------------------
//
// Before Experience existed, "Gaming Focus" (services/GameMode.qml) was a
// standalone toggle with its own toast switch
// (utilities.toasts.gameModeChanged), and video wallpapers had a
// background.video.pauseOnGameMode knob. Those are folded into the
// gaming mode: the toast switch becomes experience.toasts, an active
// GameMode becomes the gaming mode, and pauseOnGameMode keeps meaning
// "pause while the gaming mode is active". Input-modality tracking
// (services/FocusMode.qml) is a different concept and is not migrated.
//
// legacy = { gameModeEnabled: bool|undefined, hasState: bool }
// returns { state: object|null, changed: bool }
// (The toast switch is migrated by Config.migrateLegacyExperience, which
// reads the raw shell.json; see toastsFromLegacy below.)
function migrateLegacy(legacy) {
    var out = { state: null, changed: false };
    if (!legacy || typeof legacy !== "object")
        return out;
    if (!legacy.hasState && legacy.gameModeEnabled === true) {
        var st = defaultState();
        st.mode = "gaming";
        st.previous = DEFAULT_MODE;
        st.source = "migration";
        out.state = st;
        out.changed = true;
    }
    return out;
}

// Mirrors Config.migrateLegacyExperience: returns the experience.toasts
// value to adopt from a raw shell.json object, or undefined.
function toastsFromLegacy(config) {
    var legacy = config && config.utilities && config.utilities.toasts ? config.utilities.toasts.gameModeChanged : undefined;
    if (typeof legacy !== "boolean")
        return undefined;
    if (config.experience && config.experience.toasts !== undefined)
        return undefined;
    return legacy;
}

// ---- Optional automatic switching (off by default, local-only) -------

var DEFAULT_GAME_PATTERNS = ["^steam_app_[0-9]+$", "^gamescope$", "\\.exe$"];

function isGameWindow(appId, patterns) {
    if (typeof appId !== "string" || appId.length === 0)
        return false;
    var list = Array.isArray(patterns) && patterns.length > 0 ? patterns : DEFAULT_GAME_PATTERNS;
    for (var i = 0; i < list.length; i++) {
        try {
            if (new RegExp(list[i], "i").test(appId))
                return true;
        } catch (e) {
            // An invalid user pattern never matches.
        }
    }
    return false;
}

// Decides the automatic action for the current window state.
// Returns "enter" (switch to gaming), "leave" (revert an auto switch) or "".
// A user's explicit choice is never overridden: auto only leaves a mode it
// entered itself, and only enters from a mode the user did not pick as
// gaming already.
function autoDecision(st, opts) {
    if (!opts || opts.enabled !== true)
        return "";
    var game = opts.fullscreen === true && isGameWindow(opts.appId, opts.patterns);
    if (game && st.mode !== "gaming")
        return "enter";
    if (!game && st.mode === "gaming" && st.auto === true)
        return "leave";
    return "";
}

// Telemetry interval in ms for the shared providers (§6.5).
function telemetryInterval(fields, fallbackMs) {
    var hz = fields && typeof fields["telemetry.rateHz"] === "number" ? fields["telemetry.rateHz"] : 0;
    if (hz > 0)
        return Math.round(1000 / hz);
    return fallbackMs;
}

// Bar density vocabulary is glyphs|values today; labels map to values
// until bar components render eyebrows.
function barDensity(fields, specDensity) {
    var d = fields ? fields["density"] : "values";
    if (d === "icons")
        return "glyphs";
    return specDensity === "glyphs" && d !== "labels" ? "glyphs" : "values";
}

function summary() {
    var out = [];
    for (var i = 0; i < MODE_IDS.length; i++) {
        var p = FACTORY[MODE_IDS[i]];
        out.push({ id: p.id, label: p.label, glyph: p.glyph, description: p.description });
    }
    return out;
}
