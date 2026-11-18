.pragma library

// Event sound policy (Control Center > Notifications > Sounds). Pure, so it
// runs under node in tests/test_sounds_policy.py; services/Sounds.qml is the
// only QML consumer and owns the processes.

var EVENTS = ["notification", "battery", "charger"];

// event id -> freedesktop sound-naming-spec name
var FILES = {
    "notification": "message-new-instant",
    "battery": "dialog-warning",
    "charger": "power-plug"
};

// The spec's universal fallback theme.
var FALLBACK_THEME = "freedesktop";
var SOUND_ROOT = "/usr/share/sounds";

// At most one play per event kind within this window: a burst of
// notifications never stacks overlapping pw-play processes.
var MIN_GAP_MS = 500;

// A theme is a single directory name: letters, digits, "_", "-", "."; never
// "." or "..", never a path. Returns "" for anything else.
function cleanTheme(name) {
    var s = String(name === undefined || name === null ? "" : name);
    if (!/^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$/.test(s) || s.indexOf("..") >= 0)
        return "";
    return s;
}

// Files to try, in order: the chosen theme, then the spec fallback.
function candidates(theme, event) {
    var name = FILES[event];
    if (!name)
        return [];
    var out = [];
    var t = cleanTheme(theme);
    if (t.length > 0)
        out.push(SOUND_ROOT + "/" + t + "/stereo/" + name + ".oga");
    var fb = SOUND_ROOT + "/" + FALLBACK_THEME + "/stereo/" + name + ".oga";
    if (out.indexOf(fb) < 0)
        out.push(fb);
    return out;
}

// What a notification's hints say about sound (freedesktop notification
// spec): `suppress-sound` silences it; `sound-name` / `sound-file` mean the
// app asked for its own sound.
function hintInfo(hints) {
    var h = hints && typeof hints === "object" ? hints : {};
    var suppress = h["suppress-sound"];
    return {
        suppress: suppress === true || suppress === 1 || suppress === "true",
        ownSound: (typeof h["sound-name"] === "string" && h["sound-name"].length > 0) || (typeof h["sound-file"] === "string" && h["sound-file"].length > 0)
    };
}

// Decide whether an event chimes. `o`:
//   enabled, eventOn   - master switch and the event's toggle
//   quiet              - DND, held popups (Focus/Gaming)
//   critical           - a critical battery warning may override `quiet`
//   hints              - notification hints (notification event only)
//   alwaysChime        - chime even when the app names its own sound
//   now, last          - ms timestamps for the rate limit (last = 0: never)
// Returns { play, reason }.
function decide(event, o) {
    if (EVENTS.indexOf(event) < 0)
        return { play: false, reason: "unknown-event" };
    if (!o.enabled)
        return { play: false, reason: "disabled" };
    if (!o.eventOn)
        return { play: false, reason: "event-off" };
    if (o.quiet && !(event === "battery" && o.critical))
        return { play: false, reason: "quiet" };
    if (event === "notification") {
        var h = hintInfo(o.hints);
        if (h.suppress)
            return { play: false, reason: "suppress-sound" };
        if (h.ownSound && !o.alwaysChime)
            return { play: false, reason: "app-sound" };
    }
    if (o.last > 0 && o.now - o.last < MIN_GAP_MS)
        return { play: false, reason: "rate-limited" };
    return { play: true, reason: "" };
}

// Exit codes of the play script (Sounds.qml) -> a short reason.
function exitReason(code) {
    if (code === 0)
        return "";
    if (code === 3)
        return "no-file";
    if (code === 4)
        return "no-player";
    return "failed";
}
