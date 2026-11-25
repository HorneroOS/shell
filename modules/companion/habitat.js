.pragma library

// Javi's Nest as a habitat: the pure policy behind the ambient nest surface
// (settings schema and validation, per-mode intensity, the presentation
// state, which indicator lights are lit and why, and where the nest sits).
// No QML, no timers, no I/O: every function takes its inputs explicitly so
// the whole policy runs under node in tests/test_companion_habitat.py.
//
// Principles (docs/COMPANION_NEST.md):
// - Lights mean something. An indicator is lit only by a real signal the
//   shell observed (assistant connected, run in flight, approval pending,
//   radio in use, the active mode). Nothing blinks for decoration, and no
//   light ever carries private content.
// - The nest represents assistant state; it is never the security
//   authority. Approvals are decided in the approval UI, not here.
// - Quieter is always possible, never louder than the user allowed: the
//   Experience mode and quiet hours can only lower the level, and the
//   user's per-mode choices are stored, not reset when the mode changes.
// - A hidden nest is no surface at all (the host unloads it), so a hidden
//   habitat costs nothing.

// The art in assets/companion/frames/nest-*.png is the final
// illustrated clay-workshop Nest (shell 1.3.7, #716), derived through
// the deterministic art pipeline with registered masters.
var ART = { status: "final", note: "illustrated clay-workshop nest (#716)" };

var ANCHORS = ["bottom-right", "bottom-left", "top-right", "top-left"];
var PLACEMENTS = ["anchored", "withJavi"];
var LIGHTING = ["auto", "warm", "cool", "off"];
var LEVELS = ["hidden", "dim", "normal", "rich"];
var CLICK_ACTIONS = ["none", "radio", "workbench", "settings"];
var MODE_IDS = ["focus", "everyday", "signal", "gaming", "studio"];
var STATES = ["hidden", "resting", "working", "building", "sleeping", "summoned"];
var LIGHT_IDS = ["link", "run", "approval", "radio", "mode"];

// Base edge of the square nest art in logical pixels at scale 1.
var BASE_SIZE = 160;
// Where the feet rest inside the 512 px art canvas (companion_nest.py).
var FEET_Y = 472;
var CANVAS = 512;

function defaults() {
    return {
        placement: "anchored",
        anchor: "bottom-right",
        marginX: 24,
        marginY: 48,
        scale: 1.0,
        monitor: "",
        lighting: "auto",
        intensity: 0.8,
        phosphor: true,
        indicators: true,
        dimInQuietHours: true,
        // Nothing until the final nest art lands: a click target on a
        // placeholder square is a surprise, not a feature.
        clickAction: "none",
        modeLevel: { focus: "dim", everyday: "normal", signal: "rich", gaming: "hidden", studio: "dim" }
    };
}

function clampNumber(v, lo, hi, fallback) {
    return (typeof v === "number" && isFinite(v)) ? Math.max(lo, Math.min(hi, v)) : fallback;
}

// Monitor names come from the compositor (DP-1, HDMI-A-1, eDP-1 ...).
function validMonitor(name) {
    return typeof name === "string" && /^[A-Za-z0-9._:+-]{1,48}$/.test(name);
}

// Validates a persisted or edited object back to a complete, safe one.
function sanitize(raw) {
    var d = defaults();
    var o = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    if (PLACEMENTS.indexOf(o.placement) >= 0)
        d.placement = o.placement;
    if (ANCHORS.indexOf(o.anchor) >= 0)
        d.anchor = o.anchor;
    d.marginX = Math.round(clampNumber(o.marginX, 0, 400, d.marginX));
    d.marginY = Math.round(clampNumber(o.marginY, 0, 400, d.marginY));
    d.scale = Math.round(clampNumber(o.scale, 0.5, 2.0, d.scale) * 20) / 20;
    if (o.monitor === "" || validMonitor(o.monitor))
        d.monitor = o.monitor;
    if (LIGHTING.indexOf(o.lighting) >= 0)
        d.lighting = o.lighting;
    d.intensity = Math.round(clampNumber(o.intensity, 0.2, 1.0, d.intensity) * 20) / 20;
    if (typeof o.phosphor === "boolean")
        d.phosphor = o.phosphor;
    if (typeof o.indicators === "boolean")
        d.indicators = o.indicators;
    if (typeof o.dimInQuietHours === "boolean")
        d.dimInQuietHours = o.dimInQuietHours;
    if (CLICK_ACTIONS.indexOf(o.clickAction) >= 0)
        d.clickAction = o.clickAction;
    if (o.modeLevel && typeof o.modeLevel === "object") {
        for (var i = 0; i < MODE_IDS.length; i++) {
            var lv = o.modeLevel[MODE_IDS[i]];
            if (LEVELS.indexOf(lv) >= 0)
                d.modeLevel[MODE_IDS[i]] = lv;
        }
    }
    return d;
}

// The level the habitat runs at now. The mode choice is the user's; quiet
// hours can only step it down one notch (rich -> normal -> dim), never up
// and never to hidden (hiding is the user's explicit choice).
function effectiveLevel(settings, mode, inQuietHours) {
    var s = sanitize(settings);
    var level = s.modeLevel[mode] || defaults().modeLevel[mode] || "normal";
    if (inQuietHours && s.dimInQuietHours) {
        if (level === "rich")
            level = "normal";
        else if (level === "normal")
            level = "dim";
    }
    return level;
}

// Presentation state of the habitat from observed state only.
// input: { visible, storeState, running, awaitingApproval, overrideAnim }
function stateFor(input) {
    if (!input || !input.visible)
        return "hidden";
    var s = String(input.storeState || "");
    if (s === "hidden")
        return "hidden";
    if (s === "sleeping")
        return "sleeping";
    if (s === "peeking" || s === "entering" || s === "excited")
        return "summoned";
    if (s === "listening" || s === "thinking" || s === "acting" || input.running === true || input.awaitingApproval === true)
        return "working";
    if (input.overrideAnim === "work")
        return "building";
    return "resting";
}

function modeRole(mode) {
    switch (mode) {
    case "signal":
        return "signal";
    case "studio":
        return "phosphor";
    case "focus":
        return "inkMuted";
    case "gaming":
        return "alert";
    default:
        return "cue";
    }
}

// Palette role for a tone under the user's lighting choice. "auto" follows
// the live Chromatic palette; "warm" and "cool" pin the family; alerts keep
// their own role so a failure never reads as a calm amber.
function roleFor(tone, lighting, mode) {
    if (tone === "alert")
        return "alert";
    if (tone === "mode")
        return modeRole(mode);
    if (lighting === "warm")
        return "cue";
    if (lighting === "cool")
        return tone === "ok" ? "phosphor" : "signal";
    switch (tone) {
    case "ok":
        return "phosphor";
    case "activity":
        return "signal";
    default:
        return "cue";
    }
}

// Which indicator lights are lit and how.
// input: { settings, mode, level, connected, running, awaitingApproval,
//          failed, radioBusy, reducedMotion, sleeping }
// -> { link: {on, role, alpha, blink}, run: ..., approval: ..., radio: ...,
//      mode: ... }
// Blinking exists for one reason: a pending approval needs the user. It
// only blinks at level >= normal and never under reduced motion.
function lights(input) {
    var s = sanitize(input.settings);
    var level = input.level || "normal";
    var out = {};
    var live = level !== "hidden" && s.indicators && s.lighting !== "off";
    var strength = level === "dim" ? 0.4 : level === "rich" ? 1.0 : 0.8;
    if (input.sleeping)
        strength = strength * 0.5;
    var alpha = Math.round(Math.min(1, strength * s.intensity / 0.8) * 100) / 100;
    var canBlink = (level === "normal" || level === "rich") && !input.reducedMotion && !input.sleeping;
    function put(id, on, tone, blink) {
        out[id] = {
            on: live && on,
            role: roleFor(tone, s.lighting, input.mode),
            alpha: live && on ? alpha : 0,
            blink: live && on && blink && canBlink
        };
    }
    var connected = input.connected === true;
    put("link", connected || input.failed === true, input.failed === true ? "alert" : "ok", false);
    put("run", input.running === true, "activity", false);
    put("approval", input.awaitingApproval === true, "attention", true);
    put("radio", input.radioBusy === true, "activity", false);
    put("mode", true, "mode", false);
    return out;
}

// Space other shell layers reserve on each edge of a screen (the bars'
// exclusive zones). Missing or bad values count as 0.
function sanitizeInsets(raw) {
    var o = (raw && typeof raw === "object") ? raw : {};
    var out = {};
    var edges = ["left", "right", "top", "bottom"];
    for (var i = 0; i < edges.length; i++)
        out[edges[i]] = Math.round(clampNumber(o[edges[i]], 0, 4096, 0));
    return out;
}

// Size and position of the anchored nest on a screen of w x h pixels.
// The nest surface respects other layers' exclusive zones (a bar on the
// nest's corner pushes it inward), so margins are measured from the chosen
// corner of the usable area (the screen minus `insets`). Margins shrink so
// the whole nest stays inside the usable area when it fits, and on screen
// otherwise.
// -> { x, y, size } in absolute screen pixels, plus the margins the surface
//    uses from its anchored edges and which edges those are.
function layout(settings, screenW, screenH, insets) {
    var s = sanitize(settings);
    var ins = sanitizeInsets(insets);
    var size = Math.round(BASE_SIZE * s.scale);
    var left = s.anchor.indexOf("left") >= 0;
    var top = s.anchor.indexOf("top") >= 0;
    var availW = Math.max(0, screenW - ins.left - ins.right);
    var availH = Math.max(0, screenH - ins.top - ins.bottom);
    var mx = Math.max(0, Math.min(s.marginX, availW - size));
    var my = Math.max(0, Math.min(s.marginY, availH - size));
    var x = left ? ins.left + mx : screenW - ins.right - size - mx;
    var y = top ? ins.top + my : screenH - ins.bottom - size - my;
    x = Math.max(0, Math.min(x, Math.max(0, screenW - size)));
    y = Math.max(0, Math.min(y, Math.max(0, screenH - size)));
    return { x: x, y: y, size: size, marginX: mx, marginY: my, left: left, top: top };
}

// Where Javi stands when he goes home: screen fractions in the host's
// convention (posX = horizontal centre, posY = feet line). Javi's own
// surface ignores exclusive zones, so this is in full-screen coordinates
// and includes the same insets the nest surface is pushed in by.
function homeFraction(settings, screenW, screenH, insets) {
    var l = layout(settings, screenW, screenH, insets);
    return {
        fx: Math.max(0, Math.min(1, (l.x + l.size / 2) / Math.max(1, screenW))),
        fy: Math.max(0, Math.min(1, (l.y + l.size * FEET_Y / CANVAS) / Math.max(1, screenH)))
    };
}

// The one monitor the nest lives on: the user's choice when that output
// exists, else the monitor Javi was placed on, else the first (primary)
// output. Never the focused output: a home does not follow the keyboard.
function resolveScreen(monitor, javiScreen, names) {
    var list = Array.isArray(names) ? names : [];
    if (typeof monitor === "string" && monitor !== "" && list.indexOf(monitor) >= 0)
        return monitor;
    if (typeof javiScreen === "string" && javiScreen !== "" && list.indexOf(javiScreen) >= 0)
        return javiScreen;
    return list.length > 0 ? String(list[0]) : "";
}

// The assistant link light from `horneroctl assistant status --json` as the
// bridge last saw it (ok + message). Before the first probe, or while the
// assistant is switched off (the default), the light is off: off is the
// user's choice, not a failure. Red only when the assistant is enabled and
// the probe failed (gateway not answering, Hermes missing, incompatible).
// -> "unknown" | "off" | "ok" | "failed"
function linkState(input) {
    var i = input || {};
    var msg = String(i.message === undefined || i.message === null ? "" : i.message);
    if (msg === "")
        return "unknown";
    if (i.ok === true)
        return (/\bgateway reachable\b/i.test(msg) && !/unreachable/i.test(msg)) ? "ok" : "off";
    return /^assistant is enabled\b/i.test(msg) ? "failed" : "off";
}

// True when the indicator lights are drawn at all (only the finished home
// carries electronics). Blinking and the slow status probe exist only
// while this holds.
function ledsShown(settings, level, stage) {
    var s = sanitize(settings);
    return stage >= 4 && s.indicators && s.lighting !== "off" && level !== "hidden";
}

// Light socket centre/radius from manifest canvas pixels to nest pixels.
function socket(light, size) {
    var k = size / CANVAS;
    return { x: light.x * k, y: light.y * k, r: Math.max(2, light.r * k) };
}

// True when the nest should exist as a surface at all. Stage 0 is an empty
// shelf, so a nest Javi has not started building has no surface yet.
function surfaceWanted(input) {
    return input.enabled === true && input.nestEnabled === true && input.placement === "anchored" && input.level !== "hidden" && input.visible === true && input.stage > 0;
}
