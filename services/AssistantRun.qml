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

    function apply(result: var): void {
        root.run = result.state;
        for (let i = 0; i < result.intents.length; i++) {
            const name = result.intents[i].intent;
            root.intent(name, Run.intentToState(name), result.state.runId);
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

    function decided(ok: bool, denied: bool, message: string): void {
        root.apply(Run.reduce(root.run, {
            "type": "decision",
            "ok": ok,
            "denied": denied,
            "message": message
        }));
    }

    function reset(): void {
        root.apply(Run.reduce(root.run, {
            "type": "reset"
        }));
    }

    function setGateway(payload: var): void {
        root.gateway = Run.gatewayView(payload);
        root.probing = false;
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
