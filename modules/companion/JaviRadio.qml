pragma Singleton

import "radio.js" as Radio
import qs.services
import Quickshell
import QtQuick

// Javi Radio: the quick assistant's single state owner. Every entry point
// (shortcut, launcher action, clicking Javi or the nest, bar item, menu,
// IPC) funnels into openFrom(); the surface is RadioPanel.qml.
//
// Radio is a thin client over InlineAsk, the same quick ask the launcher
// uses (`horneroctl assistant ask`): no second session engine, no new
// backend path, no secrets in QML. Policy lives in radio.js (tested under
// node):
// - a question is sent only by the user's Enter in the Radio input; no
//   entry point, IPC call or extension can submit one;
// - Radio never approves, clarifies, continues a run, attaches or reads
//   the screen or clipboard. The gateway may pause the run it starts for
//   an approval; Radio then stops at "handoff", which only OFFERS the
//   Workbench/chat. The user opens it, and the chat's approval card (not
//   Radio) is where the decision is made;
// - IPC opens are untrusted (refused in Focus, Gaming and fullscreen, and
//   they never take the keyboard); only in-shell gestures do.
// The companion mirrors the real state (listening, thinking, success,
// warning, error) only while it is visible; Radio never wakes a hidden Javi.
Singleton {
    id: root

    // The surface is shown.
    property bool open: false
    // Entry point that opened it ("shortcut", "javi", ...).
    property string entry: ""
    // The panel may hold the keyboard (an in-shell gesture opened it, or
    // the user clicked the panel). IPC opens start without it.
    property bool keyboard: false
    // idle | asking | answer | handoff | failed | superseded
    property string outcome: "idle"
    property string question: ""
    property string answer: ""
    // Text placed in the input without sending it (IPC prefill).
    property string draft: ""
    // InlineAsk.generation of the question Radio sent (ownership token).
    property int askGeneration: -1
    // The final payload of a question that needs the Workbench; handed to
    // the chat only when the user presses "Open the Workbench".
    property var handoffPayload: null

    readonly property var settings: CompanionStore.radioSettings
    readonly property bool busy: root.outcome === "asking"
    readonly property bool enabled: root.settings.enabled
    // Radio started the quick ask that is in flight now.
    readonly property bool ownsAsk: root.busy && InlineAsk.busy && InlineAsk.owner === "radio" && InlineAsk.generation === root.askGeneration
    // "none" | "ondemand" | "exclusive" (radio.js focusMode)
    readonly property string focusMode: Radio.focusMode(root.open && root.keyboard, Compositor.backendId)

    // The user chose to continue in the chat/Workbench (never automatic).
    // payload: the final payload of the question that needs it, or null.
    signal handoffRequested(var payload)

    function allowed(entry: string): bool {
        return Radio.mayOpen(root.settings, entry, {
            "mode": Experience.mode,
            "fullscreen": Compositor.hasFullscreenOnFocusedOutput()
        });
    }

    function openFrom(entry: string): bool {
        const e = (entry ?? "").toString();
        if (!root.allowed(e))
            return false;
        // A fresh open never shows the previous question or answer.
        if (!root.open)
            root.reset();
        root.entry = e;
        // A second open never takes the keyboard away from a gesture, and
        // an IPC open never grants it.
        root.keyboard = root.keyboard || Radio.grantsKeyboard(e);
        root.open = true;
        root.mirror("listening");
        return true;
    }

    // An IPC request: always the untrusted class (radio.js ipcEntry).
    function openFromIpc(declared: string): bool {
        return root.openFrom(Radio.ipcEntry((declared ?? "").toString()));
    }

    // IPC prefill: open (as an IPC caller) and put text in the input. It is
    // never sent; the user reads it and presses Enter, or edits or clears
    // it. Ignored while a question is in flight.
    function prefill(declared: string, text: string): bool {
        if (!root.openFromIpc(declared))
            return false;
        if (!root.busy)
            root.draft = Radio.cleanQuestion(text);
        return true;
    }

    function toggleFrom(entry: string): bool {
        if (root.open) {
            root.close();
            return true;
        }
        return root.openFrom(entry);
    }

    // The user clicked the panel: a real gesture, so it may take the
    // keyboard now.
    function claimKeyboard(): void {
        if (root.open)
            root.keyboard = true;
    }

    // The compositor took the keyboard away (the user clicked elsewhere).
    // An idle or finished Radio closes; a question in flight keeps the
    // panel up without the keyboard, so its answer is not lost.
    function focusLost(): void {
        root.keyboard = false;
        if (!root.busy)
            root.close();
    }

    function pressEscape(): void {
        if (Radio.escapeAction(root.busy) === "cancel")
            root.cancel();
        else
            root.close();
    }

    function reset(): void {
        root.outcome = "idle";
        root.question = "";
        root.answer = "";
        root.draft = "";
        root.handoffPayload = null;
    }

    function close(): void {
        // Outcome first: cancelling flips InlineAsk.busy, and finish()
        // must not classify a run the user abandoned. Only a run Radio
        // started is cancelled; a launcher question is left alone.
        const mine = root.ownsAsk;
        root.reset();
        if (mine)
            InlineAsk.cancel("radio");
        root.open = false;
        root.keyboard = false;
        root.entry = "";
        root.mirror("idle");
    }

    // One quick question, from the user's Enter in the Radio input only.
    // Ignored when closed, empty, or already asking.
    function ask(text: string): void {
        const q = Radio.cleanQuestion(text);
        if (!root.open || q === "" || root.busy)
            return;
        root.question = q;
        root.answer = "";
        root.draft = "";
        root.handoffPayload = null;
        // The token is taken before the call: InlineAsk bumps the counter
        // synchronously inside ask().
        root.askGeneration = InlineAsk.generation + 1;
        root.outcome = "asking";
        root.mirror("thinking");
        InlineAsk.ask(q, "radio");
    }

    function cancel(): void {
        if (!root.busy)
            return;
        const mine = root.ownsAsk;
        root.outcome = "idle";
        if (mine)
            InlineAsk.cancel("radio");
        root.mirror("idle");
    }

    // The user pressed "Open the Workbench": the one way out of Radio for
    // anything that needs approval or more than a quick answer. The pending
    // payload goes with it so the chat shows the approval card; nothing is
    // decided on the way.
    function openWorkbench(): void {
        const payload = root.outcome === "handoff" ? root.handoffPayload : null;
        root.handoffRequested(payload);
        root.close();
    }

    // Presentation only: mirror the real state on the companion while it is
    // visible. Never wakes a hidden or sleeping companion.
    function mirror(state: string): void {
        if (!CompanionStore.visible || CompanionStore.state === "sleeping")
            return;
        if (state === "idle") {
            if (["listening", "thinking"].includes(CompanionStore.state))
                CompanionStore.requestState("idle");
            return;
        }
        CompanionStore.requestState(state);
    }

    function finish(): void {
        if (root.outcome !== "asking")
            return;
        const mine = InlineAsk.owner === "radio" && InlineAsk.generation === root.askGeneration;
        // Still running: nothing to classify yet.
        if (mine && InlineAsk.busy)
            return;
        // The launcher replaced the question on the shared quick ask.
        if (!mine) {
            root.outcome = "superseded";
            root.mirror("idle");
            return;
        }
        const c = InlineAsk.failed ? {
            "kind": "failed",
            "text": ""
        } : Radio.classify(InlineAsk.finalPayload, InlineAsk.text);
        root.handoffPayload = c.kind === "handoff" ? InlineAsk.finalPayload : null;
        root.outcome = c.kind;
        root.answer = c.text;
        if (!Radio.keepKeyboardAfter(Compositor.backendId))
            root.keyboard = false;
        root.mirror(c.kind === "answer" ? "success" : c.kind === "handoff" ? "warning" : "error");
        if (c.kind === "answer" && root.settings.answerBubble && CompanionStore.visible)
            CompanionStore.say(c.text.length > 240 ? c.text.slice(0, 239) + "…" : c.text, 9000);
        if (c.kind === "answer" && !root.settings.keepOpenAfterAnswer)
            root.close();
    }

    Connections {
        target: InlineAsk

        // InlineAsk drops busy before it writes the final text and failure
        // flag, so the result is read on the next event-loop turn.
        function onBusyChanged(): void {
            if (!InlineAsk.busy && root.busy)
                Qt.callLater(root.finish);
        }

        // Someone else (the launcher) started a new quick ask while Radio
        // was waiting: Radio's question is gone; say so instead of showing
        // the other surface's answer.
        function onGenerationChanged(): void {
            if (root.busy && InlineAsk.generation !== root.askGeneration)
                Qt.callLater(root.finish);
        }
    }
}
