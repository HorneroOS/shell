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
// Ask-mode contract and its documented gap: the inline ask is
// read-only by construction (it never approves, clarifies, attaches
// or executes anything itself, and pending gateway requests surface
// as the Javi-chat fallback). horneroctl exposes no `--mode` flag in
// its assistant contract (parse_assistant rejects unknown flags), so
// the shell cannot ask the gateway to suppress tool use for this
// consumer; gateway runs that would need a decision simply return a
// pending payload, which this surface never answers. See
// docs/LAUNCHER.md, "Inline AI".
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

    readonly property int textCap: InlineAskLogic.TEXT_CAP

    function ask(question: string): void {
        const q = (question ?? "").toString().trim();
        if (q === "")
            return;
        // A new query cancels any in-flight run first.
        proc.running = false;
        root.askedPrompt = q;
        root.text = "";
        root.errorText = "";
        root.finalPayload = null;
        root.failed = false;
        root.busy = true;
        proc.command = ["horneroctl", "assistant", "ask", q, "--json", "--stream"];
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
        proc.running = false;
        root.busy = false;
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

    function consume(line: string): void {
        if (!root.busy)
            return;
        const next = InlineAskLogic.applyLine({
            "text": root.text,
            "finalPayload": root.finalPayload
        }, line, root.textCap);
        root.text = next.text;
        root.finalPayload = next.finalPayload;
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
            const outcome = InlineAskLogic.finishOutcome(root.text, root.finalPayload, root.textCap);
            root.text = outcome.text;
            root.failed = outcome.failed;
            root.errorText = outcome.failed ? (outcome.errorText !== "" ? outcome.errorText : qsTr("The assistant did not answer. Check: horneroctl assistant status")) : "";
        }
    }
}
