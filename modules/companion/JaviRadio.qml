pragma Singleton

import "radio.js" as Radio
import qs.services
import Quickshell
import QtQuick

// Javi Radio: the quick assistant's single state owner. Every entry point
// (shortcut, launcher action, clicking Javi, bar item, menu, extension
// request) funnels into openFrom(); the surface is RadioPanel.qml.
//
// Radio is a thin client over InlineAsk, the same read-only quick ask the
// launcher uses: no second session engine, no new backend path, no secrets
// in QML. Policy lives in radio.js (tested under node):
// - ask-only: Radio never starts an agent run, approves, clarifies,
//   attaches or reads the screen or clipboard;
// - a question never escalates silently: a pending approval or clarification
//   ends in "handoff", which only OFFERS the Workbench/chat (the user opens
//   it), it never answers or continues the request;
// - extension requests cannot open Radio in Focus or Gaming.
// The companion mirrors the real state (listening, thinking, success,
// warning, error) only while it is visible; Radio never wakes a hidden Javi.
Singleton {
    id: root

    // The surface is shown.
    property bool open: false
    // Entry point that opened it ("shortcut", "javi", ...).
    property string entry: ""
    // idle | asking | answer | handoff | failed
    property string outcome: "idle"
    property string question: ""
    property string answer: ""

    readonly property var settings: CompanionStore.radioSettings
    readonly property bool busy: root.outcome === "asking"
    readonly property bool enabled: root.settings.enabled

    // The user chose to continue in the chat/Workbench (never automatic).
    signal handoffRequested

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
        root.entry = e;
        root.open = true;
        root.mirror("listening");
        return true;
    }

    function toggleFrom(entry: string): bool {
        if (root.open) {
            root.close();
            return true;
        }
        return root.openFrom(entry);
    }

    function close(): void {
        // Outcome first: cancelling flips InlineAsk.busy, and finish()
        // must not classify a run the user abandoned.
        root.outcome = "idle";
        InlineAsk.cancel();
        root.open = false;
        root.question = "";
        root.answer = "";
        root.mirror("idle");
    }

    // One quick question. Ignored when closed, empty, or already asking.
    function ask(text: string): void {
        const q = Radio.cleanQuestion(text);
        if (!root.open || q === "" || root.busy)
            return;
        root.question = q;
        root.answer = "";
        root.outcome = "asking";
        root.mirror("thinking");
        InlineAsk.ask(q);
    }

    function cancel(): void {
        if (!root.busy)
            return;
        root.outcome = "idle";
        InlineAsk.cancel();
        root.mirror("idle");
    }

    // The user pressed "Open the Workbench": the one way out of Radio for
    // anything that needs approval or more than a quick answer.
    function openWorkbench(): void {
        root.handoffRequested();
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
        const c = InlineAsk.failed ? {
            "kind": "failed",
            "text": ""
        } : Radio.classify(InlineAsk.finalPayload, InlineAsk.text);
        root.outcome = c.kind === "answer" ? "answer" : c.kind;
        root.answer = c.text;
        root.mirror(c.kind === "answer" ? "success" : c.kind === "handoff" ? "warning" : "error");
        if (c.kind === "answer" && root.settings.answerBubble && CompanionStore.visible)
            CompanionStore.say(c.text.length > 240 ? c.text.slice(0, 239) + "…" : c.text, 9000);
        if (c.kind === "answer" && !root.settings.keepOpenAfterAnswer)
            root.open = false;
    }

    Connections {
        target: InlineAsk

        function onBusyChanged(): void {
            if (!InlineAsk.busy)
                root.finish();
        }
    }
}
