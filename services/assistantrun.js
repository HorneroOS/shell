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

// fixed: size/length bounds below are safety limits (memory, render
// cost, the "exact request is shown whole" guarantee), not preferences.
var TEXT_CAP = 32768;
var TIMELINE_CAP = 200;
var ENTRY_CAP = 600;
var THINK_CAP = 2000;
// The exact request is never truncated silently: up to DETAIL_CAP it is
// shown whole; beyond it the card says so and Allow stays disabled.
var DETAIL_CAP = 8000;
var MARKDOWN_CAP = 20000;

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
        counter: 0,
        runMode: "",
        nextControl: "",
        denyFailed: false,
        handoff: null
    };
}

function isActive(state) {
    return !!ACTIVE[state.phase];
}

function isPending(state) {
    return !!PENDING[state.phase];
}

// Strict shape for ids that reach argv or a URL path.
function isValidRunId(id) {
    return typeof id === "string" && /^[A-Za-z0-9._-]{1,64}$/.test(id) && id !== "." && id !== "..";
}

// prompt-id or prompt-id@generation
function isValidRequestRef(ref) {
    return typeof ref === "string" && /^[A-Za-z0-9._-]{1,64}(@[0-9]{1,12})?$/.test(ref);
}

function hex4(code) {
    var h = code.toString(16).toUpperCase();
    while (h.length < 4)
        h = "0" + h;
    return h;
}

// Code points that can hide or disguise text: controls (except
// newline/tab), format characters (Cf: bidi, zero-width, tags, soft
// hyphen, ...), every space separator except the plain space, line and
// paragraph separators, variation selectors and the blank-looking
// fillers (Hangul, Braille blank, combining grapheme joiner, NEL,
// Mongolian vowel separator).
function isHiddenCodePoint(cp) {
    if (cp === 0x09 || cp === 0x0A)
        return false;
    if (cp <= 0x1F || (cp >= 0x7F && cp <= 0x9F))
        return true;
    if (cp === 0x00A0 || cp === 0x00AD || cp === 0x034F || cp === 0x061C || cp === 0x06DD || cp === 0x070F || cp === 0x08E2)
        return true;
    if ((cp >= 0x0600 && cp <= 0x0605) || cp === 0x115F || cp === 0x1160 || cp === 0x1680 || cp === 0x180E)
        return true;
    if ((cp >= 0x2000 && cp <= 0x200F) || (cp >= 0x2028 && cp <= 0x202F) || (cp >= 0x205F && cp <= 0x206F))
        return true;
    if (cp === 0x2800 || cp === 0x3000 || cp === 0x3164 || cp === 0xFEFF || cp === 0xFFA0 || (cp >= 0xFFF9 && cp <= 0xFFFB))
        return true;
    if (cp >= 0xFE00 && cp <= 0xFE0F)
        return true;
    if (cp === 0xE0001 || (cp >= 0xE0020 && cp <= 0xE007F) || (cp >= 0xE0100 && cp <= 0xE01EF))
        return true;
    return false;
}

// Makes hidden characters visible so a request cannot disguise itself.
// Returns { text, flagged, truncated }.
function visibleText(text, cap) {
    var s = (text === null || text === undefined) ? "" : text.toString();
    var truncated = s.length > cap;
    if (truncated)
        s = s.slice(0, cap);
    var flagged = false;
    var out = "";
    for (var i = 0; i < s.length;) {
        var cp = s.codePointAt(i);
        var len = cp > 0xFFFF ? 2 : 1;
        if (isHiddenCodePoint(cp)) {
            flagged = true;
            var h = cp.toString(16).toUpperCase();
            while (h.length < 4)
                h = "0" + h;
            out += "\u27E6U+" + h + "\u27E7";
        } else {
            out += s.substr(i, len);
        }
        i += len;
    }
    return { text: out, flagged: flagged, truncated: truncated };
}

function makePending(kind, runId, detail, requestId, runMode, live, choices, bound) {
    var v = visibleText(detail, DETAIL_CAP);
    // K5: a request the gateway did not describe is flagged, never shown
    // as if its text were known.
    var unbound = bound === false || (detail === null || detail === undefined ? "" : detail.toString()) === UNBOUND_APPROVAL_TEXT;
    return {
        detailBound: !unbound,
        kind: kind,
        runId: runId,
        detail: v.text,
        truncated: v.truncated,
        flagged: v.flagged,
        requestId: isValidRequestRef(requestId) ? requestId : "",
        mode: runMode || "unknown",
        choices: choices || [],
        deciding: false,
        error: "",
        live: live === true
    };
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
        return isValidRunId(text) ? { kind: "run", runId: text } : { kind: "ignore" };
    if (type === "mode")
        return { kind: "mode", mode: text };
    if (type === "approval.control")
        return isValidRequestRef(text) ? { kind: "control", ref: text } : { kind: "ignore" };
    if (type === "deny-failed")
        return { kind: "denyfailed", text: text };
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
    // Only a status glyph is stripped; a progress line ("name: delta")
    // starts with the tool name itself.
    var glyph = first === "▸" || first === "✓" || first === "✗";
    var body = glyph ? text.slice(1).trim() : text.trim();
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
//   {type:"handoff", info}                  a quick (Ask) run handed over
function reduce(prev, event) {
    var state = copy(prev);
    var intents = [];

    if (event.type === "reset") {
        var fresh = initial();
        fresh.seq = state.seq;
        fresh.counter = state.counter;
        return result(fresh, [{ intent: "rest" }]);
    }

    if (event.type === "handoff") {
        // Display only: never touches a live run or a pending decision,
        // and never becomes one (see handoffRecord).
        if (isActive(state) || isPending(state))
            return result(state, intents);
        var rec = handoffRecord(event.info);
        if (!rec)
            return result(state, intents);
        var h = initial();
        h.seq = state.seq;
        h.counter = state.counter;
        h.handoff = rec;
        return result(h, [{ intent: "attention" }]);
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
        // A decision result applies only to the request it was made on:
        // the same run, and the same bound request id (approval) or the
        // same question text (clarification). A late result for an
        // earlier request never clears a newer one.
        if (!state.pending || !decisionMatches(state.pending, event))
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
        if (f.kind === "mode") {
            state.runMode = (f.mode === "ask" || f.mode === "agent" || f.mode === "chat") ? f.mode : "unknown";
            return result(state, intents);
        }
        if (f.kind === "control") {
            state.nextControl = f.ref;
            return result(state, intents);
        }
        if (f.kind === "denyfailed") {
            // The mode's automatic deny was not accepted and the run was
            // stopped: a failure to show, never "denied".
            state.pending = null;
            state.error = clip(f.text, ENTRY_CAP);
            state.denyFailed = true;
            pushEntry(state, { kind: "commentary", text: state.error, ts: event.ts || 0 });
            intents.push({ intent: "error" });
            return result(state, intents);
        }
        if (state.phase === "starting" || state.phase === "streaming" || state.phase === "cancelling") {
            // keep going below
        }
        if (f.kind === "delta") {
            state.text = (state.text + f.text).slice(-TEXT_CAP);
            // Text never clears a pending request: only a decision on
            // that exact request, a newer request or the final result
            // does. The card stays until then.
            if (state.phase === "starting")
                state.phase = "streaming";
            if (!isPending(state))
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
            // A new request replaces any earlier one (never merges).
            state.pending = makePending("approval", state.runId, f.detail, state.nextControl, state.runMode, true, []);
            state.nextControl = "";
            pushEntry(state, { kind: "approval", text: state.pending.detail, status: "pending", ts: event.ts || 0 });
            intents.push({ intent: "attention" });
        } else if (f.kind === "clarify") {
            state.phase = "awaiting-clarification";
            state.pending = makePending("clarify", state.runId, f.detail, "", state.runMode, true, []);
            pushEntry(state, { kind: "clarify", text: state.pending.detail, status: "pending", ts: event.ts || 0 });
            intents.push({ intent: "attention" });
        } else if (f.kind === "final") {
            state.outcome = f.payload;
            var d = (f.payload && f.payload.data) || {};
            if (d.runId && !state.runId && isValidRunId(d.runId.toString()))
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
    if (isValidRunId(runId))
        state.runId = runId;
    else
        runId = "";
    var detail = (d.detail || payload.message || "").toString();
    var mode = (d.mode || state.runMode || "").toString();
    if (kind === "approval" && runId !== "") {
        var choices = (d.choices || "").toString().split(",").filter(function (c) { return c !== ""; });
        var had = state.pending && state.pending.kind === "approval";
        var shown = visibleText(detail, DETAIL_CAP).text;
        // An id carried over from the live frame is only valid for the
        // SAME displayed request; a different text drops it.
        var carried = (had && state.pending.detail === shown) ? state.pending.requestId : "";
        var req = d.request ? d.request.toString() : carried;
        state.pending = makePending("approval", runId, detail, req, mode, had ? state.pending.live : false, choices, d.detailBound === "false" || d.detailBound === false ? false : true);
        state.phase = "awaiting-approval";
        if (!had)
            pushEntry(state, { kind: "approval", text: state.pending.detail, status: "pending", ts: ts });
    } else if (kind === "clarify" && runId !== "") {
        var hadC = state.pending && state.pending.kind === "clarify";
        state.pending = makePending("clarify", runId, detail, "", mode, hadC ? state.pending.live : false, []);
        state.phase = "awaiting-clarification";
        if (!hadC)
            pushEntry(state, { kind: "clarify", text: state.pending.detail, status: "pending", ts: ts });
    }
}

// A quick (Level A) run handed to the Workbench by Radio or the
// launcher. It is a record of what that read-only run ran into, shown so
// the user sees the exact request; it is NEVER a pending decision: the
// quick run was `--mode ask` (horneroctl denies its approvals and refuses
// to approve a non-agent run) and has been denied or stopped. The only
// way forward is the user re-sending the question as a new Agent run.
// Returns null for anything without a question.
function handoffRecord(info) {
    if (!info || typeof info !== "object")
        return null;
    var q = (info.question === null || info.question === undefined) ? "" : info.question.toString().trim();
    if (q === "")
        return null;
    var kind = info.kind === "approval" || info.kind === "clarify" ? info.kind : "blocked";
    var v = visibleText(info.detail, DETAIL_CAP);
    var src = info.source === "radio" ? "radio" : "launcher";
    var vq = visibleText(q, TEXT_CAP);
    return {
        source: src,
        question: vq.text,
        questionFlagged: vq.flagged,
        kind: kind,
        detail: v.text,
        truncated: v.truncated,
        flagged: v.flagged || vq.flagged,
        runId: isValidRunId(info.runId) ? info.runId : "",
        mode: "ask",
        actionable: false
    };
}

// event: {runId, requestId, detail}. Approvals are matched by run and
// bound request id; clarifications by run and the displayed question.
function decisionMatches(pending, event) {
    if (!event || pending.runId !== (event.runId || ""))
        return false;
    if (pending.kind === "approval")
        return (event.requestId || "") === pending.requestId;
    return (event.detail || "") === pending.detail;
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
    if (pendingKind === "deny-failed" || state.denyFailed) {
        state.phase = "failed";
        intents.push({ intent: "error" });
    } else if (pendingKind === "denied-by-mode") {
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
    var view = { connection: "unknown", enabled: false, reachable: false, compatible: false, isolation: "unknown", sandboxed: false, workspace: "", detail: "", presence: "unknown" };
    if (!payload || typeof payload !== "object")
        return Object.assign(view, { connection: "disconnected", detail: "horneroctl assistant unavailable" });
    var d = payload.data || {};
    view.presence = presenceSupport(d);
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

// ---- approval user presence (hornero#447) -------------------------

// What `assistant status --json` says about approvals.requirePresence:
//   "required"  horneroctl knows --presence and requires it for approve
//   "off"       horneroctl knows it, the user turned the requirement off
//   "unknown"   an older horneroctl without the field: --presence is
//               never sent (it would reject the flag) and approve works
//               as before.
function presenceSupport(data) {
    var v = data ? data.requirePresence : undefined;
    if (v === true || v === "true")
        return "required";
    if (v === false || v === "false")
        return "off";
    return "unknown";
}

// A presence nonce: 32-128 chars of [A-Za-z0-9_-] (horneroctl's shape).
function isValidPresenceToken(token) {
    return typeof token === "string" && /^[A-Za-z0-9_-]{32,128}$/.test(token);
}

// The nonce file name for one request: `<runId>.<promptId>@<generation>`.
// Presence is bound to the full ref; a ref without a generation, or any
// invalid id, has no file (and so cannot be allowed when presence is
// required). Returns "" when invalid.
function presenceFileName(runId, requestRef) {
    if (!isValidRunId(runId) || !isValidRequestRef(requestRef) || requestRef.indexOf("@") < 0)
        return "";
    return runId + "." + requestRef;
}

// The approve argv for one decision. `presence` is the gateway's
// presenceSupport value; `token` is the nonce written for this request
// (required when presence is "required"). Deny never carries presence.
// Returns null when the decision cannot be sent safely.
function approveCommand(runId, choice, requestRef, presence, token) {
    if (!isValidRunId(runId) || (choice !== "approve" && choice !== "deny"))
        return null;
    var cmd = ["horneroctl", "assistant", "approve", runId, choice, "--json"];
    if (requestRef !== "") {
        if (!isValidRequestRef(requestRef))
            return null;
        cmd = cmd.concat(["--request", requestRef]);
    }
    if (choice === "approve" && presence === "required") {
        if (presenceFileName(runId, requestRef) === "" || !isValidPresenceToken(token))
            return null;
        cmd = cmd.concat(["--presence", token]);
    }
    return cmd;
}

// A refused decision's reason for the card (horneroctl `data.pending`).
function decisionRefusal(payload) {
    var d = payload && payload.data ? payload.data : {};
    var p = (d.pending || "").toString();
    if (p === "presence-required" || p === "presence-invalid")
        return p;
    return "";
}

// The text horneroctl shows when the gateway reports a control without a
// description (hornero#443); results also carry detailBound:"false".
var UNBOUND_APPROVAL_TEXT = "an action the gateway did not describe (deny unless you expected it)";

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
// No blacklist of tags: the two constructs that can load or inject
// are neutralised structurally with HTML entities, which Markdown
// decodes to literal characters and which are immune to backslash
// tricks:
//   "<"  -> "&lt;"      (no raw HTML, no autolink, no <img>)
//   "![" -> "&#33;["    (no image syntax, inline or reference)
// Reference definitions ("[x]: url") are dropped, and input above
// MARKDOWN_CAP is shown as plain text instead (see markdownOk). All
// operations are linear string splits, never backtracking regexes.
function stripContainerMarkers(line) {
    var t = line.replace(/^\s+/, "");
    for (var n = 0; n < 30; n++) {
        var c = t.charAt(0);
        if (c === ">") {
            t = t.slice(1).replace(/^\s+/, "");
        } else if ((c === "-" || c === "*" || c === "+") && /\s/.test(t.charAt(1))) {
            t = t.slice(1).replace(/^\s+/, "");
        } else {
            var m = /^\d{1,9}[.)]\s/.exec(t.slice(0, 12));
            if (!m)
                break;
            t = t.slice(m[0].length).replace(/^\s+/, "");
        }
    }
    return t;
}

// A link reference definition ("[x]: url"), also inside block quotes
// and list items.
function isReferenceDefinition(line) {
    var t = stripContainerMarkers(line);
    return t.charAt(0) === "[" && t.indexOf("]:") > 0 && t.indexOf("]:") < 200;
}

function safeMarkdown(text) {
    var s = (text === null || text === undefined) ? "" : text.toString();
    if (s.length > MARKDOWN_CAP)
        return s.slice(0, MARKDOWN_CAP);
    s = s.split("<").join("&lt;");
    s = s.split("![").join("&#33;[");
    var lines = s.split("\n");
    var kept = [];
    for (var i = 0; i < lines.length; i++) {
        if (isReferenceDefinition(lines[i]))
            continue;
        kept.push(lines[i]);
    }
    return kept.join("\n");
}

// Whether the text may be rendered as Markdown at all. Above the cap
// the caller must use plain text (no parser work on huge input).
function markdownOk(text) {
    return (text === null || text === undefined) ? true : text.toString().length <= MARKDOWN_CAP;
}

// Links in answers open only as web pages, and only on an explicit
// click: no file:, data:, javascript:, custom-handler or relative URL.
function isSafeLink(link) {
    return /^https?:\/\/[^\s]+$/i.test((link === null || link === undefined) ? "" : link.toString());
}
