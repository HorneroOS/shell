pragma Singleton

import "assistantrun.js" as Run
import Quickshell
import QtQuick

// Canonical assistant state for every surface (Level A quick ask,
// Level B conversation panel, Level C workbench, bar module,
// companion). Surfaces READ `run`, `gateway` and `status`; only
// AssistantBridge (the single horneroctl process owner) WRITES, via
// begin/feed/exited/cancel/decided/reset/setGateway. No surface keeps
// a private copy of run state, so they can never disagree.
//
// All transitions live in assistantrun.js (pure, tested under node).
// `intent` is the only outbound signal: a cosmetic presentation hint
// for the companion (docs/ASSISTANT_WORKBENCH.md). It carries no
// permission and cannot approve, deny or widen anything.
Singleton {
    id: root

    property var run: Run.initial()
    property var gateway: Run.gatewayView(null)
    // True while a gateway status probe is in flight after having
    // been disconnected: the UI shows "reconnecting", not a stale
    // "disconnected".
    property bool probing: false

    readonly property string status: Run.statusKey(root.gateway, root.run)
    readonly property string phase: root.run.phase
    readonly property bool active: root.phase === "starting" || root.phase === "streaming" || root.phase === "cancelling"
    readonly property bool pendingDecision: root.phase === "awaiting-approval" || root.phase === "awaiting-clarification"
    readonly property var pending: root.run.pending
    readonly property var timeline: root.run.timeline
    readonly property string runId: root.run.runId
    readonly property string answerText: root.run.text

    signal intent(string name, string companionState, string runId)

    // Last companion state emitted: identical consecutive states
    // (one `speaking` per streamed delta) are not re-announced.
    property string lastEmittedState: ""

    function apply(result: var): void {
        root.run = result.state;
        for (let i = 0; i < result.intents.length; i++) {
            const name = result.intents[i].intent;
            const st = Run.intentToState(name);
            if (st === root.lastEmittedState)
                continue;
            root.lastEmittedState = st;
            root.intent(name, st, result.state.runId);
        }
    }

    // Starts a new generation and returns its seq: the process owner
    // must pass this seq back with every line and the exit.
    function begin(mode: string, follow: bool): int {
        root.apply(Run.reduce(root.run, {
            "type": "begin",
            "mode": mode,
            "follow": follow === true
        }));
        return root.run.seq;
    }

    function feed(seq: int, line: string): void {
        root.apply(Run.reduce(root.run, {
            "type": "line",
            "seq": seq,
            "line": line,
            "ts": Date.now()
        }));
    }

    function exited(seq: int, code: int): void {
        root.apply(Run.reduce(root.run, {
            "type": "exit",
            "seq": seq,
            "code": code
        }));
    }

    function cancel(): void {
        root.apply(Run.reduce(root.run, {
            "type": "cancel"
        }));
    }

    // runId/requestId/detail name the request the decision was made on;
    // a result for any other request is dropped (assistantrun.js).
    function decided(ok: bool, denied: bool, message: string, runId: string, requestId: string, detail: string): void {
        root.apply(Run.reduce(root.run, {
            "type": "decision",
            "ok": ok,
            "denied": denied,
            "message": message,
            "runId": runId,
            "requestId": requestId,
            "detail": detail
        }));
    }

    // A quick (Ask) run handed to the Workbench: shown, never decidable
    // (assistantrun.js handoffRecord). Ignored while a run is live or a
    // decision is pending.
    function handoff(info: var): void {
        root.apply(Run.reduce(root.run, {
            "type": "handoff",
            "info": info
        }));
    }

    readonly property var handoffRecord: root.run.handoff ?? null

    function reset(): void {
        root.apply(Run.reduce(root.run, {
            "type": "reset"
        }));
    }

    function setGateway(payload: var): void {
        root.gateway = Run.gatewayView(payload);
        root.probing = false;
    }

    function safeMarkdown(text: string): string {
        return Run.safeMarkdown(text);
    }

    // Whether untrusted text may go through the Markdown renderer at all
    // (above the cap it is shown as plain text).
    function markdownOk(text: string): bool {
        return Run.markdownOk(text);
    }

    // Strict id shape for anything that reaches an argv or a URL path.
    function isValidRunId(id: string): bool {
        return Run.isValidRunId(id);
    }

    // Hidden characters made visible (⟦U+…⟧) for any untrusted text
    // shown where it could disguise itself.
    readonly property int detailCap: Run.DETAIL_CAP

    function visibleText(text: string): string {
        return Run.visibleText(text, Run.DETAIL_CAP).text;
    }

    function presenceFileName(runId: string, requestRef: string): string {
        return Run.presenceFileName(runId, requestRef);
    }

    function approveCommand(runId: string, choice: string, requestRef: string, presence: string, token: string): var {
        return Run.approveCommand(runId, choice, requestRef, presence, token);
    }

    function decisionRefusal(payload: var): string {
        return Run.decisionRefusal(payload);
    }

    function isSafeLink(link: string): bool {
        return Run.isSafeLink(link);
    }

    function traceLines(): string {
        const out = [];
        for (const e of root.run.timeline) {
            if (e.kind === "tool")
                out.push((e.status === "ok" ? "✓ " : e.status === "failed" ? "✗ " : "▸ ") + e.name + (e.preview ? ": " + e.preview : ""));
            else if (e.kind === "thinking" || e.kind === "commentary")
                out.push(e.text);
        }
        return out.join("\n").slice(-2000);
    }
}
