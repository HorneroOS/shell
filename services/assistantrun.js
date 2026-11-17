.pragma library

// Canonical assistant run state machine ("one state source").
//
// Pure and side-effect free so it runs under node in tests: the QML
// bridge owns the horneroctl Process and feeds this module typed
// inputs; this module owns every transition and returns the
// presentation intents the companion may render. Nothing here
// executes, approves or widens anything: intents are cosmetic and
// carry no permission (docs/ASSISTANT_WORKBENCH.md).
//
// Domains and who owns them (never duplicated elsewhere):
//   run      -> this module (phase, runId, text, timeline, pending)
//   gateway  -> gatewayView() over `horneroctl assistant status`
//   history  -> AssistantBridge (shell-side presentation cache)
//   session  -> horneroctl registry (read via `assistant sessions`)
//
// Race safety: every process start bumps `seq`. Inputs carry the seq
// of the process that produced them and are dropped when it is not
// the current one, so a killed/cancelled run's late stdout or exit
// can never mutate a newer run. A process that exits without a final
// CommandResult line is a disconnect, never a silent success, and
// clears all "running" activity (no stale activity after death).

var TEXT_CAP = 32768;
var TIMELINE_CAP = 200;
var ENTRY_CAP = 600;
var THINK_CAP = 2000;

var PHASES = ["idle", "starting", "streaming", "awaiting-approval", "awaiting-clarification", "cancelling", "completed", "failed", "cancelled", "disconnected", "blocked"];

var ACTIVE = { "starting": 1, "streaming": 1, "cancelling": 1 };
var PENDING = { "awaiting-approval": 1, "awaiting-clarification": 1 };

function initial() {
    return {
        seq: 0,
        phase: "idle",
        runId: "",
        mode: "",
        text: "",
        timeline: [],
        pending: null,
        error: "",
        outcome: null,
        streamClosed: true,
        activeTools: 0,
        lastIntent: "rest",
        counter: 0
    };
}

function isActive(state) {
    return !!ACTIVE[state.phase];
}

function isPending(state) {
    return !!PENDING[state.phase];
}

function clip(text, cap) {
    var s = (text === null || text === undefined) ? "" : text.toString();
    return s.length > cap ? s.slice(0, cap - 1) + "…" : s;
}

function copy(state) {
    var next = {};
    for (var k in state)
        next[k] = state[k];
    next.timeline = state.timeline.slice();
    return next;
}

// ---- frame parsing -------------------------------------------------

// Classifies one NDJSON line from `horneroctl assistant ask|events
// --json --stream`. Unknown typed frames (a `type` without `ok`) are
// ignored for forward compatibility instead of being mistaken for the
// final result; the final CommandResult always carries a boolean `ok`.
function parseFrame(line) {
    var trimmed = (line === null || line === undefined) ? "" : line.toString().trim();
    if (trimmed === "")
        return { kind: "ignore" };
    var obj = null;
    try {
        obj = JSON.parse(trimmed);
    } catch (e) {
        return { kind: "ignore" };
    }
    if (!obj || typeof obj !== "object")
        return { kind: "ignore" };
    var type = typeof obj.type === "string" ? obj.type : "";
    var text = obj.text === undefined || obj.text === null ? "" : obj.text.toString();
    if (type === "delta")
        return text !== "" ? { kind: "delta", text: text } : { kind: "ignore" };
    if (type === "run")
        return text !== "" ? { kind: "run", runId: text } : { kind: "ignore" };
    if (type === "approval" || type === "clarify")
        return { kind: type, detail: text };
    if (type === "thinking" || type === "commentary")
        return text !== "" ? { kind: type, text: text } : { kind: "ignore" };
    if (type === "tool")
        return text !== "" ? classifyTool(text) : { kind: "ignore" };
    if (typeof obj.ok === "boolean")
        return { kind: "final", payload: obj };
    return { kind: "ignore" };
}

// Tool lines come from assistant_event_trace: "▸ name[: preview]"
// (started), "✓ name" (completed), "✗ name" (failed), and
// "name: delta" (progress).
function classifyTool(text) {
    var first = text.charAt(0);
    var body = text.slice(1).trim();
    var name = body;
    var preview = "";
    var idx = body.indexOf(": ");
    if (idx > 0) {
        name = body.slice(0, idx);
        preview = body.slice(idx + 2);
    }
    if (first === "▸")
        return { kind: "tool", status: "running", name: name, preview: preview, text: text };
    if (first === "✓")
        return { kind: "tool", status: "ok", name: name, preview: "", text: text };
    if (first === "✗")
        return { kind: "tool", status: "failed", name: name, preview: "", text: text };
    return { kind: "tool", status: "progress", name: name, preview: preview, text: text };
}

// ---- reducer -------------------------------------------------------

function result(state, intents) {
    var intent = intents.length > 0 ? intents[intents.length - 1].intent : state.lastIntent;
    state.lastIntent = intent;
    return { state: state, intents: intents };
}

function pushEntry(state, entry) {
    entry.n = ++state.counter;
    var line = state.timeline.concat([entry]);
    if (line.length > TIMELINE_CAP)
        line = line.slice(line.length - TIMELINE_CAP);
    state.timeline = line;
}

function settleRunningTools(state, to) {
    var changed = false;
    var tl = state.timeline.map(function (e) {
        if (e.kind === "tool" && e.status === "running") {
            changed = true;
            var c = {};
            for (var k in e)
                c[k] = e[k];
            c.status = to;
            return c;
        }
        return e;
    });
    if (changed)
        state.timeline = tl;
    state.activeTools = 0;
}

// Events:
//   {type:"begin", mode, runId?}           a process is about to start
//   {type:"line", seq, line}                one stdout line
//   {type:"exit", seq, code}                process exited
//   {type:"cancel"}                         user asked to stop
//   {type:"stopped", seq?}                  server-side stop acknowledged
//   {type:"decision", ok, message}          approve/deny/clarify outcome
//   {type:"reset"}                          clear to idle
function reduce(prev, event) {
    var state = copy(prev);
    var intents = [];

    if (event.type === "reset") {
        var fresh = initial();
        fresh.seq = state.seq;
        fresh.counter = state.counter;
        return result(fresh, [{ intent: "rest" }]);
    }

    if (event.type === "begin") {
        var seq = state.seq + 1;
        var keepRun = event.follow === true ? state.runId : "";
        var b = initial();
        b.seq = seq;
        b.counter = state.counter;
        b.phase = "starting";
        b.mode = event.mode ? event.mode.toString() : state.mode;
        b.runId = keepRun;
        b.streamClosed = false;
        return result(b, [{ intent: "thinking" }]);
    }

    if (event.type === "cancel") {
        if (!isActive(state) && !isPending(state))
            return result(state, intents);
        state.phase = "cancelling";
        return result(state, [{ intent: "rest" }]);
    }

    if (event.type === "decision") {
        if (!state.pending)
            return result(state, intents);
        if (event.ok) {
            state.pending = null;
            state.phase = "starting";
            state.streamClosed = false;
            intents.push({ intent: event.denied ? "denied" : "thinking" });
        } else {
            state.pending = Object.assign({}, state.pending, { error: clip(event.message, ENTRY_CAP), deciding: false });
            intents.push({ intent: "attention" });
        }
        return result(state, intents);
    }

    // Everything below is process-scoped: drop stale generations.
    if (event.seq !== state.seq)
        return result(state, intents);

    if (event.type === "line") {
        var f = parseFrame(event.line);
        if (state.phase === "cancelled" || state.phase === "completed" || state.phase === "failed" || state.phase === "disconnected" || state.phase === "blocked")
            return result(state, intents);
        if (f.kind === "ignore")
            return result(state, intents);
        if (f.kind === "run") {
            state.runId = f.runId;
            return result(state, intents);
        }
        if (state.phase === "starting" || state.phase === "streaming" || state.phase === "cancelling") {
            // keep going below
        }
        if (f.kind === "delta") {
            state.text = (state.text + f.text).slice(-TEXT_CAP);
            // Answer text after a pending request means the run moved
            // on (decided elsewhere, e.g. the CLI). Trace lines alone
            // never clear a pending request: it stays answerable.
            if (isPending(state))
                state.pending = null;
            if (state.phase === "starting" || isPending(state))
                state.phase = "streaming";
            intents.push({ intent: state.activeTools > 0 ? "acting" : "speaking" });
        } else if (f.kind === "thinking") {
            var last = state.timeline[state.timeline.length - 1];
            if (last && last.kind === "thinking") {
                var merged = Object.assign({}, last, { text: clip(last.text + f.text, THINK_CAP) });
                state.timeline[state.timeline.length - 1] = merged;
            } else {
                pushEntry(state, { kind: "thinking", text: clip(f.text, THINK_CAP), ts: event.ts || 0 });
            }
            if (state.phase === "starting")
                state.phase = "streaming";
            intents.push({ intent: "thinking" });
        } else if (f.kind === "commentary") {
            pushEntry(state, { kind: "commentary", text: clip(f.text, ENTRY_CAP), ts: event.ts || 0 });
            if (state.phase === "starting")
                state.phase = "streaming";
        } else if (f.kind === "tool") {
            if (state.phase === "starting")
                state.phase = "streaming";
            if (f.status === "running") {
                state.activeTools += 1;
                pushEntry(state, { kind: "tool", name: clip(f.name, 80), preview: clip(f.preview, ENTRY_CAP), status: "running", ts: event.ts || 0 });
                intents.push({ intent: "acting" });
            } else if (f.status === "ok" || f.status === "failed") {
                var idx = -1;
                for (var i = state.timeline.length - 1; i >= 0; i--) {
                    var e = state.timeline[i];
                    if (e.kind === "tool" && e.status === "running" && e.name === f.name) {
                        idx = i;
                        break;
                    }
                }
                if (idx >= 0) {
                    state.timeline[idx] = Object.assign({}, state.timeline[idx], { status: f.status, endTs: event.ts || 0 });
                } else {
                    pushEntry(state, { kind: "tool", name: clip(f.name, 80), preview: "", status: f.status, ts: event.ts || 0 });
                }
                state.activeTools = Math.max(0, state.activeTools - (idx >= 0 ? 1 : 0));
                intents.push({ intent: state.activeTools > 0 ? "acting" : (f.status === "failed" ? "attention" : "thinking") });
            } else {
                var tl = state.timeline[state.timeline.length - 1];
                if (!tl || tl.kind !== "tool" || tl.name !== f.name)
                    pushEntry(state, { kind: "tool", name: clip(f.name, 80), preview: clip(f.preview, ENTRY_CAP), status: "running", ts: event.ts || 0 });
            }
        } else if (f.kind === "approval") {
            state.phase = "awaiting-approval";
            state.pending = { kind: "approval", runId: state.runId, detail: clip(f.detail, ENTRY_CAP), choices: [], deciding: false, error: "", live: true };
            pushEntry(state, { kind: "approval", text: clip(f.detail, ENTRY_CAP), status: "pending", ts: event.ts || 0 });
            intents.push({ intent: "attention" });
        } else if (f.kind === "clarify") {
            state.phase = "awaiting-clarification";
            state.pending = { kind: "clarify", runId: state.runId, detail: clip(f.detail, ENTRY_CAP), choices: [], deciding: false, error: "", live: true };
            pushEntry(state, { kind: "clarify", text: clip(f.detail, ENTRY_CAP), status: "pending", ts: event.ts || 0 });
            intents.push({ intent: "attention" });
        } else if (f.kind === "final") {
            state.outcome = f.payload;
            var d = (f.payload && f.payload.data) || {};
            if (d.runId && !state.runId)
                state.runId = d.runId.toString();
            // Final line handled fully at exit (single settle point),
            // but a pending payload can be applied immediately.
            applyPendingFromPayload(state, f.payload, event.ts || 0);
        }
        return result(state, intents);
    }

    if (event.type === "exit") {
        return settleExit(state, event);
    }

    return result(state, intents);
}

function applyPendingFromPayload(state, payload, ts) {
    var d = (payload && payload.data) || {};
    var kind = (d.pending || "").toString();
    var runId = (d.runId || state.runId || "").toString();
    if (runId !== "")
        state.runId = runId;
    var detail = (d.detail || payload.message || "").toString();
    if (kind === "approval" && runId !== "") {
        var choices = (d.choices || "").toString().split(",").filter(function (c) { return c !== ""; });
        var had = state.pending && state.pending.kind === "approval";
        state.pending = { kind: "approval", runId: runId, detail: clip(detail, ENTRY_CAP), choices: choices, deciding: false, error: "", live: had ? state.pending.live : false };
        state.phase = "awaiting-approval";
        if (!had)
            pushEntry(state, { kind: "approval", text: clip(detail, ENTRY_CAP), status: "pending", ts: ts });
    } else if (kind === "clarify" && runId !== "") {
        var hadC = state.pending && state.pending.kind === "clarify";
        state.pending = { kind: "clarify", runId: runId, detail: clip(detail, ENTRY_CAP), choices: [], deciding: false, error: "", live: hadC ? state.pending.live : false };
        state.phase = "awaiting-clarification";
        if (!hadC)
            pushEntry(state, { kind: "clarify", text: clip(detail, ENTRY_CAP), status: "pending", ts: ts });
    }
}

function settleExit(state, event) {
    var intents = [];
    var payload = state.outcome;
    state.streamClosed = true;
    var wasCancelling = state.phase === "cancelling";
    var pendingKind = payload && payload.data ? (payload.data.pending || "").toString() : "";

    if (isPending(state) && (payload === null || pendingKind === "approval" || pendingKind === "clarify")) {
        // Stream ended while a decision is outstanding: the run still
        // waits server-side, so the request stays answerable. Honest
        // flag: the live stream is closed.
        settleRunningTools(state, "unknown");
        if (state.pending)
            state.pending = Object.assign({}, state.pending, { live: false });
        intents.push({ intent: "attention" });
        return result(state, intents);
    }
    if (wasCancelling) {
        settleRunningTools(state, "cancelled");
        state.phase = "cancelled";
        state.pending = null;
        intents.push({ intent: "rest" });
        return result(state, intents);
    }
    if (payload === null) {
        // Died without a CommandResult: never a success.
        settleRunningTools(state, "unknown");
        state.phase = "disconnected";
        state.pending = null;
        state.error = state.text !== "" ? "stream-interrupted" : "no-answer";
        intents.push({ intent: "error" });
        return result(state, intents);
    }
    if (payload.ok === true) {
        settleRunningTools(state, "unknown");
        state.phase = "completed";
        state.pending = null;
        if (state.text === "" && payload.data && payload.data.text)
            state.text = clip(payload.data.text, TEXT_CAP);
        intents.push({ intent: "success" });
        return result(state, intents);
    }
    settleRunningTools(state, "unknown");
    state.pending = null;
    state.error = clip((payload.message || "").toString(), ENTRY_CAP);
    if (pendingKind === "denied-by-mode") {
        state.phase = "blocked";
        intents.push({ intent: "denied" });
    } else {
        state.phase = "failed";
        intents.push({ intent: "error" });
    }
    return result(state, intents);
}

// ---- presentation intents -----------------------------------------

// Intents are cosmetic. Mapping to companion states lives here so the
// reaction bus and the legacy requestState path agree. Intents never
// carry or imply permission; `attention` is "something needs you",
// not "approved".
var INTENT_STATE = {
    "rest": "idle",
    "thinking": "thinking",
    "speaking": "thinking",
    "acting": "acting",
    "attention": "warning",
    "success": "success",
    "denied": "denied",
    "error": "error",
    "listening": "listening"
};

function intentToState(intent) {
    return INTENT_STATE[intent] || "idle";
}

// ---- gateway/status view ------------------------------------------

// Folds `horneroctl assistant status --json` (payload) and the
// gateway isolation field into one honest connection view. `run` is
// the run state to combine with (or null). Never reports "sandboxed"
// unless the backend said bubblewrap.
function gatewayView(payload) {
    var view = { connection: "unknown", enabled: false, reachable: false, compatible: false, isolation: "unknown", sandboxed: false, workspace: "", detail: "" };
    if (!payload || typeof payload !== "object")
        return Object.assign(view, { connection: "disconnected", detail: "horneroctl assistant unavailable" });
    var d = payload.data || {};
    view.enabled = d.enabled === "true";
    view.detail = (payload.message || "").toString();
    if (!view.enabled) {
        view.connection = "disabled";
        return view;
    }
    view.reachable = d.gateway === "reachable";
    view.workspace = d.workspace ? d.workspace.toString() : "";
    view.compatible = d.protocol === "compatible";
    if (d.isolation) {
        view.isolation = d.isolation.toString();
        view.sandboxed = view.isolation === "bubblewrap";
    }
    if (!view.reachable)
        view.connection = "disconnected";
    else if (!view.compatible)
        view.connection = "incompatible";
    else
        view.connection = "connected";
    return view;
}

// One user-facing status key combining gateway and run domains.
// Priority: run problems and pending decisions outrank a calm
// "connected"; a disconnected gateway outranks everything because
// nothing can run.
function statusKey(gateway, run) {
    var g = gateway ? gateway.connection : "unknown";
    if (g === "disabled")
        return "disabled";
    if (g === "disconnected")
        return "disconnected";
    if (g === "incompatible")
        return "degraded";
    if (run) {
        if (run.phase === "awaiting-approval")
            return "awaiting-approval";
        if (run.phase === "awaiting-clarification")
            return "awaiting-clarification";
        if (run.phase === "starting" || run.phase === "streaming" || run.phase === "cancelling")
            return "running";
        if (run.phase === "blocked")
            return "blocked";
        if (run.phase === "failed" || run.phase === "disconnected")
            return "failed";
    }
    if (g === "connected" && gateway && gateway.isolation !== "unknown" && !gateway.sandboxed)
        return "degraded-isolation";
    if (g === "connected")
        return "connected";
    return "unknown";
}

// ---- scripted replay (tests + fake backend) ------------------------

// Feeds raw NDJSON lines through the reducer as one process (begin,
// lines, exit) and returns { state, intents }. Used by tests and by
// the fake-backend harness to prove a scenario end to end.
function replay(lines, opts) {
    var o = opts || {};
    var s = initial();
    var all = [];
    var r = reduce(s, { type: "begin", mode: o.mode || "agent" });
    s = r.state;
    all = all.concat(r.intents);
    var seq = s.seq;
    for (var i = 0; i < lines.length; i++) {
        r = reduce(s, { type: "line", seq: seq, line: lines[i], ts: i + 1 });
        s = r.state;
        all = all.concat(r.intents);
    }
    if (o.exit !== false) {
        r = reduce(s, { type: "exit", seq: seq, code: o.code === undefined ? 0 : o.code });
        s = r.state;
        all = all.concat(r.intents);
    }
    return { state: s, intents: all };
}

// ---- untrusted text hardening --------------------------------------

// Model and tool output is untrusted. Rendering it as Markdown must
// not make the shell fetch anything (a remote image is an exfiltration
// channel: the URL can carry data) and must not pass raw HTML through.
// Images become an inert note; dangerous raw tags are dropped.
function safeMarkdown(text) {
    var s = (text === null || text === undefined) ? "" : text.toString();
    s = s.replace(/!\[([^\]]*)\]\s*\([^)]*\)/g, function (m, alt) {
        return "[image omitted" + (alt ? ": " + alt : "") + "]";
    });
    s = s.replace(/!\[([^\]]*)\]\s*\[[^\]]*\]/g, function (m, alt) {
        return "[image omitted" + (alt ? ": " + alt : "") + "]";
    });
    s = s.replace(/<\s*\/?\s*(img|iframe|script|object|embed|link|style|svg|video|audio|source|meta|base|form)\b[^>]*>/gi, "");
    return s;
}

// Links in answers open only as web pages, and only on an explicit
// click: no file:, data:, javascript:, custom-handler or relative URL.
function isSafeLink(link) {
    return /^https?:\/\/[^\s]+$/i.test((link === null || link === undefined) ? "" : link.toString());
}
