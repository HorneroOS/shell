.pragma library

// Pure streaming state machine for the launcher inline ask
// (shell#250 slice 3). InlineAsk.qml owns the horneroctl Process;
// this module owns the NDJSON line semantics so tests can execute
// them under node: delta lines append (capped), thinking/tool/
// commentary trace lines never become answer text, any other
// JSON line is the final CommandResult payload, and finishOutcome
// classifies the run for the UI (answer vs. Javi-chat fallback).
// No logging happens here or in the QML wrapper: the question and
// the answer are never written to any log.

var TEXT_CAP = 16384;

function parseLine(line) {
    var trimmed = (line === null || line === undefined) ? "" : line.toString().trim();
    if (trimmed === "")
        return { kind: "ignore" };
    var obj = null;
    try {
        obj = JSON.parse(trimmed);
    } catch (e) {
        obj = null;
    }
    if (!obj)
        return { kind: "ignore" };
    if (obj.type === "delta")
        return obj.text ? { kind: "delta", text: obj.text.toString() } : { kind: "ignore" };
    if (obj.type === "thinking" || obj.type === "tool" || obj.type === "commentary")
        return { kind: "trace" };
    return { kind: "final", payload: obj };
}

// Applies one streamed line to { text, finalPayload } and returns
// the next state. Trace and malformed lines change nothing.
function applyLine(state, line, cap) {
    var limit = (typeof cap === "number" && cap > 0) ? cap : TEXT_CAP;
    var text = state && state.text ? state.text.toString() : "";
    var finalPayload = state && state.finalPayload !== undefined ? state.finalPayload : null;
    var parsed = parseLine(line);
    if (parsed.kind === "delta")
        text = (text + parsed.text).slice(-limit);
    else if (parsed.kind === "final")
        finalPayload = parsed.payload;
    return { text: text, finalPayload: finalPayload };
}

// Classifies a finished run. failed=true means the inline ask
// produced no answer and the UI must offer the Javi-chat fallback
// (never a dead end, never a fabricated answer).
function finishOutcome(text, finalPayload, cap) {
    var limit = (typeof cap === "number" && cap > 0) ? cap : TEXT_CAP;
    var current = text ? text.toString() : "";
    if (finalPayload && finalPayload.ok === false) {
        return {
            text: current,
            errorText: (finalPayload.message || "").toString(),
            failed: true
        };
    }
    if (current === "" && finalPayload && finalPayload.data && finalPayload.data.text) {
        return {
            text: finalPayload.data.text.toString().slice(-limit),
            errorText: "",
            failed: false
        };
    }
    if (current === "" && !finalPayload) {
        return { text: current, errorText: "", failed: true };
    }
    return { text: current, errorText: "", failed: false };
}
