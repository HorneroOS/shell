.pragma library

// Javi Radio: the pure policy for the quick assistant (settings schema and
// validation, which entry points are open, and the escalation rule). No QML,
// no timers, no I/O; runs under node in tests/test_javi_radio.py.
//
// Security contract (docs/JAVI_RADIO.md, ADR 002):
// - Radio is ask-only. It never starts an agent run, never approves or
//   clarifies, never attaches files and never reads the clipboard or the
//   screen. It talks through the same assistant path as the launcher quick
//   ask; the backend and horneroctl policy stay the authority.
// - A quick question never silently escalates. When the backend reports a
//   pending approval or clarification, Radio stops and tells the user to
//   continue in the Workbench; it cannot answer the request itself.
// - Entry points only open the radio; none of them can run anything.

var ENTRY_POINTS = ["shortcut", "launcher", "javi", "bar", "plugin", "menu"];
var CLICK_ACTIONS = ["radio", "tip", "chat", "none"];
var DEFAULT_SHORTCUT = "Super+Shift+J";
var QUESTION_MAX = 600;
var ANSWER_MAX = 4000;

function defaults() {
    return {
        enabled: true,
        shortcut: DEFAULT_SHORTCUT,
        entryPoints: { shortcut: true, launcher: true, javi: true, bar: true, plugin: true, menu: true },
        clickOnJavi: "radio",
        showInBar: true,
        keepOpenAfterAnswer: true,
        answerBubble: true
    };
}

// Shortcut text is a display and binding hint: "Mod+Mod+Key" with known
// modifiers and one key. Anything else falls back to the default.
function validShortcut(text) {
    if (typeof text !== "string")
        return false;
    return /^((Super|Ctrl|Alt|Shift)\+){1,3}([A-Za-z0-9]|F([1-9]|1[0-2])|Space|Return|Tab|Escape)$/.test(text.trim());
}

function sanitize(raw) {
    var d = defaults();
    var o = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    if (typeof o.enabled === "boolean")
        d.enabled = o.enabled;
    if (validShortcut(o.shortcut))
        d.shortcut = o.shortcut.trim();
    if (o.entryPoints && typeof o.entryPoints === "object") {
        for (var i = 0; i < ENTRY_POINTS.length; i++) {
            if (typeof o.entryPoints[ENTRY_POINTS[i]] === "boolean")
                d.entryPoints[ENTRY_POINTS[i]] = o.entryPoints[ENTRY_POINTS[i]];
        }
    }
    if (CLICK_ACTIONS.indexOf(o.clickOnJavi) >= 0)
        d.clickOnJavi = o.clickOnJavi;
    if (typeof o.showInBar === "boolean")
        d.showInBar = o.showInBar;
    if (typeof o.keepOpenAfterAnswer === "boolean")
        d.keepOpenAfterAnswer = o.keepOpenAfterAnswer;
    if (typeof o.answerBubble === "boolean")
        d.answerBubble = o.answerBubble;
    return d;
}

// Whether `entry` may open the radio now. The master switch wins, then the
// per-entry switch; an unknown entry is always refused. Extension requests
// are not a user gesture, so they never open Radio in the quiet modes
// (Focus, Gaming); the user's own shortcut, click or launcher always can.
// Under a fullscreen window nothing opens (the panel would sit beneath it
// while holding the keyboard), so a game or video is never interrupted.
// ctx: { mode, fullscreen } (the active Experience mode; fullscreen on the
// focused output).
function mayOpen(settings, entry, ctx) {
    var s = sanitize(settings);
    if (ENTRY_POINTS.indexOf(entry) < 0)
        return false;
    if (ctx && ctx.fullscreen === true)
        return false;
    if (entry === "plugin" && ctx && (ctx.mode === "focus" || ctx.mode === "gaming"))
        return false;
    return s.enabled && s.entryPoints[entry] === true;
}

// One line, bounded, no control characters (the question is user text).
function cleanQuestion(text) {
    var t = String(text === undefined || text === null ? "" : text).replace(/[\u0000-\u001f\u007f-\u009f\u2028-\u202e\u2066-\u2069]/g, " ").replace(/\s+/g, " ").trim();
    return t.length > QUESTION_MAX ? t.slice(0, QUESTION_MAX) : t;
}

// Classifies a finished quick ask for Radio.
// payload: the final CommandResult (`{ ok, message, data: { pending, text } }`
// as horneroctl emits it); streamed: the live text InlineAsk accumulated.
// -> { kind: "answer" | "handoff" | "failed", text }
// "handoff" is the escalation rule: a pending approval or clarification (or
// a blocked run) is never answered here, whatever text came with it.
function classify(payload, streamed) {
    var p = (payload && typeof payload === "object") ? payload : {};
    var d = (p.data && typeof p.data === "object") ? p.data : {};
    var pending = String(d.pending === undefined || d.pending === null ? "" : d.pending);
    if (pending === "approval" || pending === "clarify" || pending !== "" || d.blocked === true || p.status === "blocked" || p.status === "awaiting_approval")
        return { kind: "handoff", text: "" };
    if (p.ok === false)
        return { kind: "failed", text: "" };
    var text = (typeof streamed === "string" && streamed !== "") ? streamed : (typeof d.text === "string" ? d.text : "");
    if (text === "")
        return { kind: "failed", text: "" };
    return { kind: "answer", text: text.length > ANSWER_MAX ? text.slice(0, ANSWER_MAX) : text };
}
