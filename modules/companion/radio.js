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
// - Entry points only open the radio; none of them can run anything, and
//   none can submit a question: only the user's Enter in the Radio input
//   asks.
// - Two trust classes. User gestures handled inside the shell (the global
//   shortcut, the launcher action, clicking Javi or the nest, the bar item,
//   Javi's menu) may open Radio with the keyboard. Anything arriving over
//   `qs ipc` cannot be authenticated (any local process can call it): it is
//   the `plugin` class (refused in Focus, Gaming and under fullscreen, opens
//   without keyboard focus), except the opt-in `keybind` entry for
//   compositor key bindings, which may take the keyboard but is off by
//   default and refused in the quiet modes, because it is just as forgeable.

var ENTRY_POINTS = ["shortcut", "launcher", "javi", "bar", "plugin", "menu", "nest", "keybind"];
// Gestures the shell itself observed; never reachable over IPC.
var GESTURE_ENTRIES = ["shortcut", "launcher", "javi", "bar", "menu", "nest"];
// Entries an IPC caller may name (anything else is treated as "plugin").
var IPC_ENTRIES = ["plugin", "keybind"];
var CLICK_ACTIONS = ["radio", "tip", "chat", "none"];
var DEFAULT_SHORTCUT = "Super+Shift+J";
var QUESTION_MAX = 600;
var ANSWER_MAX = 4000;

function defaults() {
    return {
        enabled: true,
        shortcut: DEFAULT_SHORTCUT,
        entryPoints: { shortcut: true, launcher: true, javi: true, bar: true, plugin: true, menu: true, nest: true, keybind: false },
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

// True for the in-shell user gestures (see the trust classes above).
function isGesture(entry) {
    return GESTURE_ENTRIES.indexOf(entry) >= 0;
}

// The entry an IPC call is treated as, whatever it claims: "keybind" when
// it says so (opt-in, documented as unauthenticated), otherwise "plugin".
// An IPC caller can never borrow a gesture entry such as "shortcut".
function ipcEntry(declared) {
    return IPC_ENTRIES.indexOf(declared) >= 0 ? declared : "plugin";
}

// Whether `entry` may open the radio now. The master switch wins, then the
// per-entry switch; an unknown entry is always refused. IPC entries are not
// a verified user gesture, so they never open Radio in the quiet modes
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
    if (!isGesture(entry) && ctx && (ctx.mode === "focus" || ctx.mode === "gaming"))
        return false;
    return s.enabled && s.entryPoints[entry] === true;
}

// Whether opening from `entry` may take the keyboard at once. Extension
// (plugin) opens never do: the panel shows, and the user clicks it to type.
function grantsKeyboard(entry) {
    return isGesture(entry) || entry === "keybind";
}

// Layer-shell keyboard mode for the panel: "none" without a grant; with
// one, "ondemand" (the compositor moves focus away when the user clicks
// another window, so Radio never keeps the keyboard behind their back),
// except on niri, which does not focus an on-demand top-layer surface
// opened from a shortcut, so it gets "exclusive" only while the user is
// typing a question (see keepKeyboardAfter).
function focusMode(keyboard, compositor) {
    if (keyboard !== true)
        return "none";
    return compositor === "niri" ? "exclusive" : "ondemand";
}

// Whether the panel keeps its keyboard grant once a question finishes.
// Exclusive (niri) gives it back, so an answer left on screen never holds
// the keyboard; a click on the panel claims it again.
function keepKeyboardAfter(compositor) {
    return compositor !== "niri";
}

// Escape: stop the question in flight, otherwise close.
function escapeAction(busy) {
    return busy === true ? "cancel" : "close";
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
// No final payload at all (the process was killed or died mid-stream) is
// never an answer, even with partial streamed text.
function classify(payload, streamed) {
    if (!payload || typeof payload !== "object")
        return { kind: "failed", text: "" };
    var p = payload;
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
