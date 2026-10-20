pragma ComponentBehavior: Bound

import qs.modules.companion
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Assistant bridge (Javi / Hermes): the only companion-side piece that
// talks to the assistant backend, through the public horneroctl CLI —
// never to Hermes directly, never around horneroctl's consent gates.
//
// Chat flow (shell#234): ask() runs
// `horneroctl assistant ask <text> --json --stream [--attach …]`,
// which frames live text as NDJSON delta lines and ends with the
// final CommandResult JSON line. Deltas grow `streamText` (rendered
// live by the panel); the final line resolves the run: answer,
// pending approval, or pending clarification — surfaced from the
// structured payload, never parsed out of prose. Approvals and
// clarifications are always explicit user actions forwarded through
// horneroctl, the only holder of the gateway credential.
//
// History is shell-side presentation state: persisted (capped) at
// $XDG_STATE_HOME/hornero/companion/chat-history.json so a restart
// keeps the conversation; Hermes owns real sessions. The user can
// clear it at any time. Attachments are validated by horneroctl
// (allowlist + caps + secret-path refusal); voice notes are recorded
// locally and sent as an audio attachment that Hermes transcribes.
Scope {
    id: root

    property string buffer: ""
    property string lineBuffer: ""
    property string decisionBuffer: ""
    property bool busy: false
    property var history: []
    property string lastRunId: ""
    property string lastPrompt: ""
    property var pendingApproval: null
    property var pendingClarify: null
    property bool chatOpen: false
    // Live streamed assistant text for the in-flight run.
    property string streamText: ""
    // Activity trace of the current/last run: provider reasoning
    // previews, tool lifecycle and commentary, as emitted by the
    // gateway (never the model's raw chain-of-thought).
    property string traceText: ""
    property var finalPayload: null
    // Backend status for the panel header / settings pane.
    property bool assistantEnabled: false
    property bool gatewayReachable: false
    property string statusMessage: ""
    // Named chat sessions (hornero#189): Hermes owns the real
    // conversations; horneroctl's registry names the continuity
    // keys. Empty currentSession = gateway default conversation.
    property var chatSessions: []
    property string currentSession: ""
    property string currentModel: ""

    function refreshSessions(): void {
        sessionsProc.out = "";
        sessionsProc.command = ["horneroctl", "assistant", "sessions", "--json"];
        sessionsProc.running = true;
        modelProc.out = "";
        modelProc.command = ["horneroctl", "assistant", "model", "list", "--json"];
        modelProc.running = true;
    }

    function newChatSession(): void {
        const title = qsTr("Chat %1").arg(new Date().toLocaleTimeString());
        sessionActionProc.out = "";
        sessionActionProc.command = ["horneroctl", "assistant", "sessions", "new", title, "--json"];
        sessionActionProc.running = true;
        root.clearHistory();
    }

    function useChatSession(id: string): void {
        if (id === root.currentSession)
            return;
        sessionActionProc.out = "";
        sessionActionProc.command = ["horneroctl", "assistant", "sessions", "use", id, "--json"];
        sessionActionProc.running = true;
        root.clearHistory();
    }

    function cycleChatSession(): void {
        if (root.chatSessions.length === 0)
            return;
        let idx = root.chatSessions.findIndex(s => s.id === root.currentSession);
        idx = (idx + 1) % root.chatSessions.length;
        root.useChatSession(root.chatSessions[idx].id);
    }

    readonly property string currentSessionTitle: {
        for (const s of root.chatSessions)
            if (s.id === root.currentSession)
                return s.title;
        return qsTr("Default chat");
    }

    // Attachments queued for the next send (absolute paths).
    property var attachments: []
    property bool recording: false
    property string recordPath: ""

    readonly property string historyPath: `${Paths.state}/companion/chat-history.json`
    readonly property int historyCap: CompanionStore.chatHistoryLimit > 0 ? CompanionStore.chatHistoryLimit : 50

    function pushHistory(role: string, text: string): void {
        root.pushHistoryTraced(role, text, "");
    }

    function pushHistoryTraced(role: string, text: string, trace: string): void {
        const entry = {
            "role": role,
            "text": text,
            "trace": trace ? trace.toString().slice(-2000) : "",
            "ts": Date.now()
        };
        let next = root.history.concat([entry]);
        if (next.length > root.historyCap)
            next = next.slice(next.length - root.historyCap);
        root.history = next;
        root.saveHistory();
    }

    function clearHistory(): void {
        root.history = [];
        root.saveHistory();
    }

    function saveHistory(): void {
        const text = JSON.stringify(root.history);
        if (text === root.lastSavedHistory)
            return;
        root.lastSavedHistory = text;
        const quoted = text.replace(/'/g, "'\\''");
        const path = root.historyPath;
        historyWriter.command = ["sh", "-c", `mkdir -p "$(dirname '${path}')" && tmp="$(mktemp "$(dirname '${path}')/.chat.XXXXXX")" && printf '%s' '${quoted}' > "$tmp" && mv -f "$tmp" '${path}'`];
        historyWriter.running = true;
    }

    property string lastSavedHistory: ""

    function loadHistory(): void {
        historyReader.path = root.historyPath;
        historyReader.reload();
    }

    function notePayload(payload): void {
        if (!payload)
            return;
        const data = payload.data || {};
        if (data.runId)
            root.lastRunId = data.runId.toString();
        const pending = (data.pending || "").toString();
        const detail = (data.detail || payload.message || "").toString();
        if (pending === "approval" && root.lastRunId !== "") {
            root.pendingApproval = {
                "runId": root.lastRunId,
                "detail": detail
            };
            root.pendingClarify = null;
            CompanionStore.requestState("warning");
        } else if (pending === "clarify" && root.lastRunId !== "") {
            root.pendingClarify = {
                "runId": root.lastRunId,
                "detail": detail
            };
            root.pendingApproval = null;
            CompanionStore.requestState("warning");
        }
    }

    function handleFinalLine(line: string): void {
        let payload = null;
        try {
            payload = JSON.parse(line);
        } catch (e) {
            payload = null;
        }
        if (!payload || payload.type === "delta")
            return;
        root.finalPayload = payload;
    }

    // SplitParser hands us one NDJSON line per read (delimiter
    // stripped): a {type:delta} line grows the live text, anything
    // else that parses is the final CommandResult line.
    function consumeChunk(data: string): void {
        const line = (data ?? "").toString().trim();
        if (line === "")
            return;
        let obj = null;
        try {
            obj = JSON.parse(line);
        } catch (e) {
            obj = null;
        }
        if (obj && obj.type === "delta" && obj.text)
            root.streamText += obj.text.toString();
        else if (obj && obj.type === "thinking" && obj.text)
            root.traceText = (root.traceText + obj.text.toString()).slice(-8000);
        else if (obj && (obj.type === "tool" || obj.type === "commentary") && obj.text) {
            const line = obj.text.toString();
            root.traceText = ((root.traceText === "" || root.traceText.endsWith("\n")) ? root.traceText + line + "\n" : root.traceText + "\n" + line + "\n").slice(-8000);
        } else if (obj)
            root.finalPayload = obj;
    }

    function ask(text: string): void {
        const prompt = (text ?? "").toString().trim();
        if (prompt === "" && root.attachments.length === 0)
            return;
        if (root.busy) {
            CompanionStore.say("Still working on the last one — give me a moment.", 4000);
            return;
        }
        const sentAttachments = root.attachments.slice();
        root.attachments = [];
        root.buffer = "";
        root.lineBuffer = "";
        root.streamText = "";
        root.finalPayload = null;
        root.busy = true;
        root.traceText = "";
        root.lastPrompt = prompt;
        const shown = prompt === "" ? qsTr("(attachment)") : prompt;
        root.pushHistory("user", sentAttachments.length > 0 ? `${shown} 📎 ${sentAttachments.length}` : shown);
        CompanionStore.requestState("thinking");
        let cmd = ["horneroctl", "assistant", "ask", prompt === "" ? qsTr("Describe and answer based on the attached file(s).") : prompt, "--json", "--stream"];
        if (root.currentSession !== "")
            cmd = cmd.concat(["--session", root.currentSession]);
        for (const p of sentAttachments)
            cmd = cmd.concat(["--attach", p.toString()]);
        askProcess.command = cmd;
        askProcess.running = true;
    }

    // Copy the latest assistant answer to the clipboard (wl-copy).
    function copyLastAnswer(): void {
        for (let i = root.history.length - 1; i >= 0; i--) {
            if (root.history[i].role === "assistant") {
                copyProcess.command = ["wl-copy", root.history[i].text.toString()];
                copyProcess.running = true;
                CompanionStore.say("Answer copied.", 3000);
                return;
            }
        }
        CompanionStore.say("Nothing to copy yet.", 3000);
    }

    function retryLast(): void {
        if (root.lastPrompt !== "" && !root.busy)
            root.ask(root.lastPrompt);
    }

    function addAttachment(path: string): void {
        const p = (path ?? "").toString().trim();
        if (p === "" || root.attachments.indexOf(p) !== -1)
            return;
        if (root.attachments.length >= 8) {
            CompanionStore.say("Up to 8 attachments per message.", 4000);
            return;
        }
        root.attachments = root.attachments.concat([p]);
    }

    function removeAttachment(path: string): void {
        root.attachments = root.attachments.filter(p => p !== path);
    }

    // Voice: record with pw-record (PipeWire) to a temp wav; on stop,
    // the clip is attached and sent with a transcription instruction.
    // Hermes transcribes audio attachments gateway-side; the shell
    // never touches STT credentials.
    function startRecording(): void {
        if (root.recording || root.busy)
            return;
        root.recordPath = `${Quickshell.cacheDir}/javi-voice-${Date.now()}.wav`;
        recordProcess.command = ["pw-record", "--rate", "16000", "--channels", "1", root.recordPath];
        recordProcess.running = true;
        root.recording = true;
        CompanionStore.requestState("listening");
    }

    function stopRecording(send: bool): void {
        if (!root.recording)
            return;
        root.recording = false;
        recordProcess.running = false;
        CompanionStore.requestState("idle");
        if (send && root.recordPath !== "") {
            root.addAttachment(root.recordPath);
            root.ask(qsTr("Transcribe the attached audio and treat the transcription as my message. Answer it."));
        }
    }

    // Approval / clarification UX: decisions are always explicit user
    // actions. Nothing here answers Hermes on its own.
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
        if (id === "" || text === "")
            return;
        root.decisionBuffer = "";
        decisionProcess.command = ["horneroctl", "assistant", "clarify", id, text, "--json"];
        decisionProcess.running = true;
    }

    function refreshStatus(): void {
        statusProcess.command = ["horneroctl", "assistant", "status", "--json"];
        statusProcess.running = true;
    }

    function askStop(): void {
        if (!root.busy)
            return;
        askProcess.running = false;
        root.busy = false;
        if (root.streamText !== "") {
            root.pushHistory("assistant", root.streamText + " ⏹");
            root.streamText = "";
        }
        CompanionStore.requestState("idle");
        if (root.lastRunId !== "") {
            // Server-side cancel (shell#223): stop the Hermes run too,
            // not just the local CLI process.
            stopProcess.command = ["horneroctl", "assistant", "stop", root.lastRunId, "--json"];
            stopProcess.running = true;
            CompanionStore.say("Stopped — including the Hermes run.", 5000);
        } else {
            CompanionStore.say("Stopped locally; the run id was not known yet.", 5000);
        }
    }

    Component.onCompleted: {
        root.loadHistory();
        root.refreshStatus();
        root.refreshSessions();
    }

    FileView {
        id: historyReader

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed))
                    root.history = parsed.filter(e => e && e.text).slice(-root.historyCap);
            } catch (e) {
                root.history = [];
            }
        }
    }

    Process {
        id: sessionsProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                sessionsProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(sessionsProc.out.trim());
                const d = payload.data ?? {};
                root.currentSession = (d.current ?? "").toString();
                const ids = (d.ids ?? "").toString().split(",").filter(s => s !== "");
                const lines = (payload.message ?? "").toString().split("\n");
                root.chatSessions = ids.map(id => {
                    let title = id;
                    for (const line of lines) {
                        const m = line.match(new RegExp(id + " — (.*) \\(since"));
                        if (m)
                            title = m[1];
                    }
                    return {
                        "id": id,
                        "title": title
                    };
                });
            } catch (e) {
                root.chatSessions = [];
            }
        }
    }

    Process {
        id: sessionActionProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                sessionActionProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => root.refreshSessions()
    }

    Process {
        id: modelProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                modelProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(modelProc.out.trim());
                root.currentModel = ((payload.data ?? {}).model ?? "").toString();
            } catch (e) {
                root.currentModel = "";
            }
        }
    }

    Process {
        id: historyWriter
    }

    Process {
        id: copyProcess
    }

    Process {
        id: recordProcess

        onExited: (exitCode, exitStatus) => {
            root.recording = false;
        }
    }

    Process {
        id: statusProcess

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                statusProcess.out += data;
            }
        }
        onStarted: statusProcess.out = ""
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(statusProcess.out.trim());
                root.assistantEnabled = payload.ok === true;
                root.statusMessage = payload.message ? payload.message.toString() : "";
                root.gatewayReachable = root.statusMessage.indexOf("reachable") !== -1;
            } catch (e) {
                root.assistantEnabled = false;
                root.gatewayReachable = false;
                root.statusMessage = "horneroctl assistant unavailable";
            }
        }
    }

    Process {
        id: stopProcess
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
                root.pendingClarify = null;
                CompanionStore.requestState("success");
                CompanionStore.say(payload.message.toString(), 9000);
                // The run continues after a decision; follow its events.
                if (root.lastRunId !== "")
                    root.followEvents(root.lastRunId);
            } else if (payload && payload.message) {
                CompanionStore.requestState("error");
                CompanionStore.say(payload.message.toString(), 9000);
            } else {
                CompanionStore.requestState("error");
                CompanionStore.say("The decision was not recorded. Check: horneroctl assistant status", 9000);
            }
        }
    }

    function followEvents(runId: string): void {
        if (root.busy)
            return;
        root.lineBuffer = "";
        root.streamText = "";
        root.finalPayload = null;
        root.busy = true;
        CompanionStore.requestState("thinking");
        askProcess.command = ["horneroctl", "assistant", "events", runId, "--json", "--stream"];
        askProcess.running = true;
    }

    Process {
        id: askProcess

        stdout: SplitParser {
            onRead: data => {
                root.consumeChunk(data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            // Flush any unterminated trailing line.
            if (root.lineBuffer.trim() !== "") {
                root.handleFinalLine(root.lineBuffer.trim());
                root.lineBuffer = "";
            }
            const payload = root.finalPayload;
            const streamed = root.streamText;
            root.streamText = "";
            root.notePayload(payload);
            if (payload && payload.data && (payload.data.pending === "approval" || payload.data.pending === "clarify")) {
                if (streamed !== "")
                    root.pushHistoryTraced("assistant", streamed, root.traceText);
                root.pushHistory("system", (payload.data.detail || payload.message || "").toString());
            } else if (payload && payload.ok === true) {
                const finalText = streamed !== "" ? streamed : (payload.data && payload.data.text ? payload.data.text.toString() : "");
                if (finalText !== "") {
                    root.pushHistoryTraced("assistant", finalText, root.traceText);
                    CompanionStore.requestState("success");
                    CompanionStore.say(finalText, 12000);
                } else {
                    CompanionStore.requestState("success");
                }
            } else if (payload && payload.message) {
                root.pushHistory("system", payload.message.toString());
                CompanionStore.requestState("error");
                CompanionStore.say(payload.message.toString(), 9000);
            } else if (streamed !== "") {
                root.pushHistoryTraced("assistant", streamed, root.traceText);
                CompanionStore.requestState("success");
            } else {
                CompanionStore.requestState("error");
                CompanionStore.say("The assistant did not answer. Check: horneroctl assistant status", 9000);
            }
        }
    }
}
