pragma Singleton

import "inlineask.js" as InlineAskLogic
import Quickshell
import Quickshell.Io
import QtQuick

// Inline Javi ask for the launcher (shell#250 slice 3): `>ai <question>`
// streams the answer inside the launcher instead of only summoning the
// chat panel. Same trust path as the chat: the shell only runs
// `horneroctl assistant ask --json --stream`; it never talks to Hermes
// directly and never holds the gateway credential. Approvals and
// clarifications are NOT answered here -- the final payload says so and
// the user continues in the Javi chat panel.
//
// Ask-mode contract: the inline ask is read-only by construction. It
// runs `--mode ask` (horneroctl auto-denies approvals and stops any
// run that tries a tool in that mode), never approves, clarifies,
// attaches or executes anything itself, and a pending gateway request
// ends the quick run and offers an EXPLICIT hand-off to the Workbench
// (`needsWorkbench`). A quick question never silently escalates to
// agent operations. See docs/LAUNCHER.md, "Inline AI".
//
// Privacy: the question and answer are never logged (no console
// output anywhere on this path), no network endpoint is added, and
// nothing is persisted -- the last question/answer live only in this
// singleton's memory until the next ask or a shell restart. Real
// conversation history is owned by Hermes/the chat panel, not here.
Singleton {
    id: root

    property bool busy: false
    property string text: ""
    property string errorText: ""
    property string askedPrompt: ""
    property var finalPayload: null
    // True when a run ended without an answer: the row offers the
    // previous summon-Javi behaviour instead of a dead end.
    property bool failed: false
    // Quick questions never act: when the gateway asks for a decision
    // (or the read-only mode blocks a tool) the run is stopped and the
    // row offers an explicit hand-off to the Workbench instead.
    property bool needsWorkbench: false
    property string runId: ""
    property string pending: ""
    // Set by `companion quick`: the launcher opens with this query.
    property string prefill: ""

    readonly property int textCap: InlineAskLogic.TEXT_CAP

    function ask(question: string): void {
        const q = (question ?? "").toString().trim();
        if (q === "")
            return;
        // A new query cancels any in-flight run first (server side too).
        root.cancel();
        root.askedPrompt = q;
        root.text = "";
        root.errorText = "";
        root.finalPayload = null;
        root.failed = false;
        root.needsWorkbench = false;
        root.runId = "";
        root.pending = "";
        root.busy = true;
        // `--mode ask` is the read-only contract (hornero#414/#415):
        // fail closed rather than fall back to the agent default when
        // horneroctl is too old to know the flag.
        proc.command = ["horneroctl", "assistant", "ask", "--json", "--stream", "--mode", "ask", "--", q];
        proc.running = true;
    }

    function stop(): void {
        root.cancel();
    }

    // Cancels the in-flight run (Escape/launcher close, leaving the
    // ai state, or a new query). Partial streamed text is kept;
    // the killed process's exit is ignored because busy is false.
    function cancel(): void {
        if (!root.busy && !proc.running)
            return;
        root.stopRun();
        proc.running = false;
        root.busy = false;
    }

    // Every cancel path (Escape, launcher close, a new query, shell
    // exit) asks the gateway to stop the run too: killing only the
    // local process would leave an Ask run running. When the run id is
    // not known yet the user is told, because the run may continue.
    function stopRun(): void {
        if (root.runId !== "" && /^[A-Za-z0-9._-]{1,64}$/.test(root.runId)) {
            stopProc.running = false;
            stopProc.running = true;
        } else if (root.busy) {
            // The launcher may be closing: a toast survives it.
            Quickshell.execDetached(["quickshell", "ipc", "call", "toaster", "warn", "Javi", qsTr("Stopped locally; the run may still be going on the gateway (its id was not known yet)."), "alert-triangle"]);
        }
    }

    Component.onDestruction: {
        if (root.busy && root.runId !== "" && /^[A-Za-z0-9._-]{1,64}$/.test(root.runId))
            Quickshell.execDetached(["horneroctl", "assistant", "stop", root.runId, "--json"]);
    }

    // Previous `>ai` behaviour (shell#216): summon Javi through the
    // companion IPC with the same question and close the launcher.
    // Used only as the explicit fallback when the inline ask fails.
    function openInJavi(list: var): void {
        const q = root.askedPrompt.trim();
        if (q === "")
            return;
        Quickshell.execDetached(["quickshell", "ipc", "call", "companion", "ask", q]);
        if (list)
            list.visibilities.launcher = false;
    }

    // Explicit user hand-off (click on the row): same question in the
    // Workbench, where approvals/attachments/long runs belong.
    function openInWorkbench(list: var): void {
        const q = root.askedPrompt.trim();
        if (q === "")
            return;
        Quickshell.execDetached(["quickshell", "ipc", "call", "companion", "workbenchDraft", q]);
        if (list)
            list.visibilities.launcher = false;
    }

    function consume(line: string): void {
        if (!root.busy)
            return;
        const next = InlineAskLogic.applyLine({
            "text": root.text,
            "finalPayload": root.finalPayload,
            "runId": root.runId,
            "pending": root.pending
        }, line, root.textCap);
        root.text = next.text;
        root.finalPayload = next.finalPayload;
        root.runId = next.runId;
        if (next.pending !== "" && root.pending === "") {
            root.pending = next.pending;
            root.needsWorkbench = true;
            // Do not leave a blocked run waiting: stop it server-side
            // (this is a stop, never an approval) and end the stream.
            if (root.runId !== "")
                stopProc.running = true;
            proc.running = false;
            root.busy = false;
        }
    }

    Process {
        id: stopProc

        command: ["horneroctl", "assistant", "stop", root.runId, "--json"]
    }

    Process {
        id: proc

        stdout: SplitParser {
            onRead: data => root.consume(data)
        }
        onExited: (exitCode, exitStatus) => {
            // Cancelled runs also exit; only a still-busy run
            // resolves here, so a stale exit can never clobber a
            // newer query's state.
            if (!root.busy)
                return;
            root.busy = false;
            root.needsWorkbench = InlineAskLogic.needsWorkbench(root.pending, root.finalPayload);
            const outcome = InlineAskLogic.finishOutcome(root.text, root.finalPayload, root.textCap);
            root.text = outcome.text;
            root.failed = outcome.failed;
            root.errorText = outcome.failed ? (outcome.errorText !== "" ? outcome.errorText : qsTr("The assistant did not answer. Check: horneroctl assistant status")) : "";
        }
    }
}
