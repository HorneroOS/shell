pragma ComponentBehavior: Bound

import qs.modules.companion
import Quickshell
import Quickshell.Io
import QtQuick

// Assistant bridge (Hermes slice 1): the only companion-side piece that
// talks to the assistant backend, through the public horneroctl CLI —
// never to Hermes directly, never around horneroctl's consent gates.
//
// Flow: ask(text) marks the reserved `thinking` state, runs
// `horneroctl assistant ask --json <text>`, then shows the answer in the
// speech bubble under `success`, or a short recovery line under `error`.
// When the assistant is disabled or Hermes is down, horneroctl answers
// ok:false with a human message; the bridge surfaces it verbatim
// (truncated by say()) so the failure is honest, not a silent no-op.
//
// Cancellation is local in this slice: askStop() terminates the CLI
// process. The Hermes run may finish server-side; full run-id cancel
// lands when the ask protocol streams run ids (see
// docs/COMPANION_ASSISTANT.md).
Scope {
    id: root

    property string buffer: ""
    property string decisionBuffer: ""
    property bool busy: false
    // Chat surface state: in-memory conversation history (never
    // persisted by the shell; Hermes owns sessions), the last run
    // id seen, and a pending approval awaiting the user's decision.
    property var history: []
    property string lastRunId: ""
    property var pendingApproval: null
    property bool chatOpen: false

    function pushHistory(role: string, text: string): void {
        const entry = {
            "role": role,
            "text": text
        };
        const next = root.history.concat([entry]);
        root.history = next.length > 20 ? next.slice(next.length - 20) : next;
    }

    function notePayload(payload): void {
        if (!payload)
            return;
        if (payload.data && payload.data.runId)
            root.lastRunId = payload.data.runId.toString();
        const msg = payload.message ? payload.message.toString() : "";
        const marker = "waiting for approval on run ";
        const idx = msg.indexOf(marker);
        if (idx >= 0) {
            const rest = msg.slice(idx + marker.length);
            const runId = rest.split(":")[0].trim();
            if (runId !== "") {
                root.pendingApproval = {
                    "runId": runId,
                    "detail": msg
                };
                CompanionStore.requestState("warning");
            }
        }
    }

    function ask(text: string): void {
        const prompt = (text ?? "").toString().trim();
        if (prompt === "")
            return;
        if (root.busy) {
            CompanionStore.say("Still working on the last one — give me a moment.", 4000);
            return;
        }
        root.buffer = "";
        root.busy = true;
        root.pushHistory("user", prompt);
        CompanionStore.requestState("thinking");
        askProcess.command = ["horneroctl", "assistant", "ask", prompt, "--json"];
        askProcess.running = true;
    }

    // Approval / clarification UX: decisions are always explicit user
    // actions. Nothing here answers Hermes on its own; each function
    // forwards exactly the decision the user picked through horneroctl,
    // which remains the only holder of the gateway credential.
    function approve(runId: string, decision: string): void {
        const id = (runId ?? "").toString().trim();
        const choice = (decision ?? "").toString().trim();
        if (id === "" || (choice !== "approve" && choice !== "deny")) {
            CompanionStore.say("I need a run id and an approve or deny decision.", 6000);
            return;
        }
        root.decisionBuffer = "";
        decisionProcess.command = ["horneroctl", "assistant", "approve", id, choice, "--json"];
        decisionProcess.running = true;
    }

    function clarify(runId: string, answer: string): void {
        const id = (runId ?? "").toString().trim();
        const text = (answer ?? "").toString().trim();
        if (id === "" || text === "") {
            CompanionStore.say("I need a run id and your answer.", 6000);
            return;
        }
        root.decisionBuffer = "";
        decisionProcess.command = ["horneroctl", "assistant", "clarify", id, text, "--json"];
        decisionProcess.running = true;
    }

    function events(runId: string): void {
        const id = (runId ?? "").toString().trim();
        if (id === "" || root.busy)
            return;
        root.buffer = "";
        root.busy = true;
        CompanionStore.requestState("thinking");
        askProcess.command = ["horneroctl", "assistant", "events", id, "--json"];
        askProcess.running = true;
    }

    function askStop(): void {
        if (!root.busy)
            return;
        askProcess.running = false;
        root.busy = false;
        CompanionStore.requestState("idle");
        CompanionStore.say("Stopped. The answer may still finish on the Hermes side.", 5000);
    }

    Process {
        id: decisionProcess

        stdout: SplitParser {
            onRead: data => {
                root.decisionBuffer += data;
            }
        }

        onExited: (exitCode, exitStatus) => {
            let payload = null;
            try {
                payload = JSON.parse(root.decisionBuffer.trim());
            } catch (e) {
                payload = null;
            }
            if (payload && payload.ok === true && payload.message) {
                root.pendingApproval = null;
                CompanionStore.requestState("success");
                CompanionStore.say(payload.message.toString(), 9000);
            } else if (payload && payload.message) {
                CompanionStore.requestState("error");
                CompanionStore.say(payload.message.toString(), 9000);
            } else {
                CompanionStore.requestState("error");
                CompanionStore.say("The decision was not recorded. Check: horneroctl assistant status", 9000);
            }
        }
    }

    Process {
        id: askProcess

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            let payload = null;
            try {
                payload = JSON.parse(root.buffer.trim());
            } catch (e) {
                payload = null;
            }
            root.notePayload(payload);
            if (payload && payload.ok === true && payload.message) {
                root.pushHistory("assistant", payload.message.toString());
                CompanionStore.requestState("success");
                CompanionStore.say(payload.message.toString(), 12000);
            } else if (payload && payload.message) {
                CompanionStore.requestState("error");
                CompanionStore.say(payload.message.toString(), 9000);
            } else {
                CompanionStore.requestState("error");
                CompanionStore.say("The assistant did not answer. Check: horneroctl assistant status", 9000);
            }
        }
    }
}
