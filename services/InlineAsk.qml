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
        if (root.stopPending) {
            // A previous cancel is still waiting for its run id: do not
            // start a second process over it.
            root.stopPending = false;
            deferTimer.stop();
            proc.running = false;
            root.warnNotStopped();
        }
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
        root.busy = false;
        if (InlineAskLogic.validRunId(root.runId)) {
            root.stopRun(root.runId);
            proc.running = false;
        } else if (proc.running) {
            // The run id is not known yet (the gateway has not answered
            // the run creation). Killing now would orphan a run that is
            // about to start, so the process is kept just long enough to
            // learn the id and stop it (see consume()); a deadline kills
            // it and tells the user.
            root.stopPending = true;
            deferTimer.restart();
        }
    }

    // Every cancel path (Escape, launcher close, a new query, shell
    // exit) asks the gateway to stop the run too: killing only the
    // local process would leave an Ask run running. The id is captured
    // into the command here, so a later reset of `runId` cannot change
    // what is stopped; a failed stop is reported.
    function stopRun(id: string): void {
        if (!InlineAskLogic.validRunId(id))
            return;
        stopProc.running = false;
        stopProc.command = ["horneroctl", "assistant", "stop", id, "--json"];
        stopProc.running = true;
    }

    function warnNotStopped(): void {
        // The launcher may be closing: a toast survives it.
        Quickshell.execDetached(["quickshell", "ipc", "call", "toaster", "warn", "Javi", qsTr("Stopped locally; the run may still be going on the gateway (its id was not known yet)."), "alert-triangle"]);
    }

    property bool stopPending: false

    Timer {
        id: deferTimer

        // fixed: how long a cancel waits for the run id before giving
        // up (a safety deadline, not a preference).
        interval: 8000
        onTriggered: {
            if (root.stopPending) {
                root.stopPending = false;
                proc.running = false;
                root.warnNotStopped();
            }
        }
    }

    Component.onDestruction: {
        if (root.busy && InlineAskLogic.validRunId(root.runId))
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
        if (!root.busy && !root.stopPending)
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
        if (root.stopPending) {
            // A cancel was waiting for the id: stop the run, end the stream.
            if (InlineAskLogic.validRunId(root.runId)) {
                root.stopPending = false;
                deferTimer.stop();
                root.stopRun(root.runId);
                proc.running = false;
            }
            return;
        }
        if (next.pending !== "" && root.pending === "") {
            root.pending = next.pending;
            root.needsWorkbench = true;
            // Do not leave a blocked run waiting: stop it server-side
            // (this is a stop, never an approval) and end the stream.
            root.stopRun(root.runId);
            proc.running = false;
            root.busy = false;
        }
    }

    Process {
        id: stopProc

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["quickshell", "ipc", "call", "toaster", "warn", "Javi", qsTr("The stop request was not accepted. The run may still be going: horneroctl assistant status"), "alert-triangle"]);
        }
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
