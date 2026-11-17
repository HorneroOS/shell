pragma ComponentBehavior: Bound

import qs.modules.companion
import qs.services
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

    property string decisionBuffer: ""
    property var history: []
    property string lastPrompt: ""
    property bool chatOpen: false
    // Level C (workbench) is the same panel expanded, never a second
    // engine: it reads the very same AssistantRun state.
    property bool workbenchOpen: false
    property bool decisionBusy: false
    // Backend status for the panel header / settings pane. Derived
    // from the canonical gateway view (AssistantRun.gateway).
    readonly property bool assistantEnabled: AssistantRun.gateway.enabled
    readonly property bool gatewayReachable: AssistantRun.gateway.reachable
    property string statusMessage: ""
    // Decisions made this session (what was decided, never secrets).
    property var decisions: []
    // Files attached and sent this session (paths only, no content).
    property var sentArtifacts: []

    // Compatibility surface for the panel and IPC: all of these are
    // read-only views over the one canonical run state.
    readonly property bool busy: AssistantRun.active
    readonly property string streamText: AssistantRun.active || AssistantRun.pendingDecision ? AssistantRun.answerText : ""
    readonly property string traceText: AssistantRun.traceLines()
    readonly property string lastRunId: AssistantRun.runId
    readonly property var pendingApproval: AssistantRun.pending && AssistantRun.pending.kind === "approval" ? AssistantRun.pending : null
    readonly property var pendingClarify: AssistantRun.pending && AssistantRun.pending.kind === "clarify" ? AssistantRun.pending : null

    // Named chat sessions (hornero#189): Hermes owns the real
    // conversations; horneroctl's registry names the continuity
    // keys. Empty currentSession = gateway default conversation.
    property var chatSessions: []
    property string currentSession: ""
    property string currentModel: ""
    property string currentProvider: ""
    property var modelChoices: []

    function refreshSessions(): void {
        sessionsProc.out = "";
        sessionsProc.command = ["horneroctl", "assistant", "sessions", "--json"];
        sessionsProc.running = true;
        modelProc.out = "";
        modelProc.command = ["horneroctl", "assistant", "model", "show", "--json"];
        modelProc.running = true;
        modelListProc.out = "";
        modelListProc.command = ["horneroctl", "assistant", "model", "list", "--json"];
        modelListProc.running = true;
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

    // ---- run control ------------------------------------------------
    // The bridge owns the horneroctl processes; AssistantRun owns the
    // state. Every process start takes a generation (seq) from
    // AssistantRun.begin and passes it back with each line and the
    // exit, so a cancelled run's late output can never touch a newer
    // run (see services/assistantrun.js).
    property int askSeq: 0

    function ask(text: string): void {
        const prompt = (text ?? "").toString().trim();
        if (prompt === "" && root.attachments.length === 0)
            return;
        if (root.busy || AssistantRun.pendingDecision) {
            CompanionStore.say(AssistantCopy.t("status.running", root.lang), 4000);
            return;
        }
        const sentAttachments = root.attachments.slice();
        root.attachments = [];
        root.lastPrompt = prompt;
        const shown = prompt === "" ? qsTr("(attachment)") : prompt;
        root.pushHistory("user", sentAttachments.length > 0 ? `${shown} 📎 ${sentAttachments.length}` : shown);
        root.noteArtifacts(sentAttachments);
        root.askSeq = AssistantRun.begin(CompanionStore.chatMode, false);
        root.clearPendingSnapshot();
        let cmd = ["horneroctl", "assistant", "ask", prompt === "" ? qsTr("Describe and answer based on the attached file(s).") : prompt, "--json", "--stream", "--mode", CompanionStore.chatMode];
        if (root.currentSession !== "")
            cmd = cmd.concat(["--session", root.currentSession]);
        for (const p of sentAttachments)
            cmd = cmd.concat(["--attach", p.toString()]);
        askProcess.command = cmd;
        askProcess.running = true;
    }

    function noteArtifacts(paths: var): void {
        if (!paths || paths.length === 0)
            return;
        let next = root.sentArtifacts.slice();
        for (const p of paths)
            next.push({
                "path": p.toString(),
                "ts": Date.now()
            });
        root.sentArtifacts = next.slice(-50);
    }

    // Copy the latest assistant answer to the clipboard (wl-copy). An
    // explicit user action; nothing reads the clipboard.
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

    // Voice: record with pw-record (PipeWire) to a wav in the shell
    // cache; on stop, the clip is attached and sent with a
    // transcription instruction. The microphone is only ever opened by
    // an explicit click, shows its state (`recording`, elapsed
    // seconds), can be discarded without sending, auto-stops after
    // two minutes, and the file is deleted once the run ends. Hermes
    // transcribes gateway-side; the shell never touches STT keys.
    property int recordSeconds: 0
    readonly property int recordMaxSeconds: 120

    function startRecording(): void {
        if (root.recording || root.busy)
            return;
        root.recordPath = `${Quickshell.cacheDir}/javi-voice-${Date.now()}.wav`;
        recordProcess.command = ["pw-record", "--rate", "16000", "--channels", "1", root.recordPath];
        recordProcess.running = true;
        root.recordSeconds = 0;
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
        } else {
            root.discardRecording();
        }
    }

    function discardRecording(): void {
        if (root.recordPath === "")
            return;
        rmProcess.command = ["rm", "-f", "--", root.recordPath];
        rmProcess.running = true;
        root.recordPath = "";
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: {
            root.recordSeconds += 1;
            if (root.recordSeconds >= root.recordMaxSeconds) {
                root.stopRecording(false);
                CompanionStore.say(AssistantCopy.t("mic.auto-stopped", root.lang), 5000);
            }
        }
    }

    // Approval / clarification UX: decisions are always explicit user
    // actions on a specific run. Nothing here answers Hermes on its
    // own, there is no "approve all", and `approve` is the single
    // action `once` on the backend.
    function approve(runId: string, decision: string): void {
        const id = (runId ?? "").toString().trim();
        const choice = (decision ?? "").toString().trim();
        if (id === "" || (choice !== "approve" && choice !== "deny")) {
            CompanionStore.say("I need a run id and an approve or deny decision.", 6000);
            return;
        }
        if (root.decisionBusy)
            return;
        // The decision must name the run that is actually waiting:
        // a stale card/IPC call cannot decide a different run.
        const pend = AssistantRun.pending;
        if (!pend || pend.kind !== "approval" || pend.runId !== id) {
            CompanionStore.say(qsTr("That request is no longer waiting."), 5000);
            return;
        }
        root.decisionBusy = true;
        root.decisionBuffer = "";
        root.decisionKind = "approval";
        root.decisionDenied = choice === "deny";
        root.decisionDetail = pend.detail;
        decisionProcess.command = ["horneroctl", "assistant", "approve", id, choice, "--json"];
        decisionProcess.running = true;
    }

    function clarify(runId: string, answer: string): void {
        const id = (runId ?? "").toString().trim();
        const text = (answer ?? "").toString().trim();
        if (id === "" || text === "" || root.decisionBusy)
            return;
        const pend = AssistantRun.pending;
        if (!pend || pend.kind !== "clarify" || pend.runId !== id) {
            CompanionStore.say(qsTr("That question is no longer waiting."), 5000);
            return;
        }
        root.decisionBusy = true;
        root.decisionBuffer = "";
        root.decisionKind = "clarify";
        root.decisionDenied = false;
        root.decisionDetail = pend.detail;
        decisionProcess.command = ["horneroctl", "assistant", "clarify", id, text, "--json"];
        decisionProcess.running = true;
    }

    property string decisionKind: ""
    property bool decisionDenied: false
    property string decisionDetail: ""

    readonly property string lang: AssistantCopy.lang(Qt.locale().name)

    function refreshStatus(): void {
        if (!AssistantRun.gateway.reachable)
            AssistantRun.probing = true;
        statusProcess.command = ["horneroctl", "assistant", "status", "--json"];
        statusProcess.running = true;
    }

    // Cancel: server-side stop first (the run id is known from the
    // typed `run` frame as soon as the run exists), then the local
    // process. The reducer settles to `cancelled`, not to success.
    function askStop(): void {
        if (!root.busy && !AssistantRun.pendingDecision)
            return;
        const id = AssistantRun.runId;
        const partial = AssistantRun.answerText;
        const wasPending = AssistantRun.pendingDecision;
        AssistantRun.cancel();
        if (id !== "") {
            stopProcess.command = ["horneroctl", "assistant", "stop", id, "--json"];
            stopProcess.running = true;
            CompanionStore.say(qsTr("Stopped, including the Hermes run."), 5000);
        } else {
            CompanionStore.say(qsTr("Stopped locally; the run id was not known yet."), 5000);
        }
        if (askProcess.running)
            askProcess.running = false;
        else
            AssistantRun.exited(AssistantRun.run.seq, 0);
        if (partial !== "" && !wasPending)
            root.pushHistory("assistant", partial + " ⏹");
        root.clearPendingSnapshot();
    }

    // ---- restart safety ---------------------------------------------
    // A pending approval/question outlives the shell: the run waits
    // server-side. A tiny snapshot (run id, kind, redacted detail) is
    // written while a request is pending and verified on startup
    // against the gateway (`assistant events <run>` checks the run
    // status), so a restart neither loses a live request nor shows a
    // stale one. Nothing else about the run is persisted.
    readonly property string pendingPath: `${Paths.state}/companion/pending-request.json`

    function savePendingSnapshot(): void {
        const pend = AssistantRun.pending;
        if (!pend)
            return;
        const text = JSON.stringify({
            "runId": pend.runId,
            "kind": pend.kind,
            "detail": pend.detail
        });
        pendingWriter.exec(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"", "sh", root.pendingPath, text]);
    }

    function clearPendingSnapshot(): void {
        pendingWriter.exec(["rm", "-f", "--", root.pendingPath]);
    }

    function verifyRestoredRequest(snap: var): void {
        if (!snap || !snap.runId || root.busy)
            return;
        root.restoreSeq = AssistantRun.begin(CompanionStore.chatMode, false);
        root.restoreRun = snap.runId.toString();
        restoreProcess.out = "";
        restoreProcess.command = ["horneroctl", "assistant", "events", root.restoreRun, "--json"];
        restoreProcess.running = true;
    }

    property string snapshotKey: ""
    property int restoreSeq: 0
    property string restoreRun: ""

    Connections {
        target: AssistantRun

        function onPendingChanged(): void {
            const pend = AssistantRun.pending;
            const key = pend ? `${pend.runId}|${pend.kind}|${pend.detail}` : "";
            if (key === root.snapshotKey)
                return;
            root.snapshotKey = key;
            if (pend)
                root.savePendingSnapshot();
            else
                root.clearPendingSnapshot();
        }

        // Companion presentation: cosmetic only, no permission.
        function onIntent(name: string, companionState: string, runId: string): void {
            CompanionStore.requestState(companionState);
        }
    }

    Component.onCompleted: {
        root.loadHistory();
        root.refreshStatus();
        root.refreshSessions();
        pendingReader.path = root.pendingPath;
        pendingReader.reload();
    }

    FileView {
        id: pendingReader

        onLoaded: {
            try {
                root.verifyRestoredRequest(JSON.parse(text()));
            } catch (e) {
                // No snapshot (or unreadable): nothing to restore.
            }
        }
    }

    Process {
        id: pendingWriter

        function exec(cmd: var): void {
            pendingWriter.running = false;
            pendingWriter.command = cmd;
            pendingWriter.running = true;
        }
    }

    Process {
        id: rmProcess
    }

    Process {
        id: restoreProcess

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                restoreProcess.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            const seq = root.restoreSeq;
            const body = restoreProcess.out.trim();
            if (body !== "")
                AssistantRun.feed(seq, body);
            AssistantRun.exited(seq, exitCode);
            // Not pending anymore (decided, finished or expired): the
            // reducer shows no request; do not surface a stale run.
            if (!AssistantRun.pending)
                AssistantRun.reset();
        }
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
                root.currentProvider = ((payload.data ?? {}).provider ?? "").toString();
            } catch (e) {
                root.currentModel = "";
                root.currentProvider = "";
            }
        }
    }

    Process {
        id: modelListProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                modelListProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(modelListProc.out.trim());
                root.modelChoices = ((payload.data ?? {}).models ?? "").toString().split(",").filter(m => m !== "");
            } catch (e) {
                root.modelChoices = [];
            }
        }
    }

    // Explicit model change (same horneroctl verb as Control Center;
    // applies to new sessions). Never invoked implicitly.
    function applyModel(id: string): void {
        const m = (id ?? "").toString().trim();
        if (m === "" || m.indexOf(" ") !== -1)
            return;
        modelSetProc.command = ["horneroctl", "assistant", "model", "set", m, "--yes", "--json"];
        modelSetProc.running = true;
    }

    Process {
        id: modelSetProc

        onExited: (exitCode, exitStatus) => root.refreshSessions()
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
            let payload = null;
            try {
                payload = JSON.parse(statusProcess.out.trim());
            } catch (e) {
                payload = null;
            }
            AssistantRun.setGateway(payload);
            root.statusMessage = payload && payload.message ? payload.message.toString() : "horneroctl assistant unavailable";
        }
    }

    // While disconnected and the panel is open, re-probe gently so
    // "Disconnected" becomes "Connected" without a manual refresh.
    Timer {
        interval: 15000
        repeat: true
        running: root.chatOpen && AssistantRun.gateway.connection !== "connected" && AssistantRun.gateway.connection !== "disabled"
        onTriggered: root.refreshStatus()
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
            root.decisionBusy = false;
            let payload = null;
            try {
                payload = JSON.parse(root.decisionBuffer.trim());
            } catch (e) {
                payload = null;
            }
            const ok = !!(payload && payload.ok === true);
            const message = payload && payload.message ? payload.message.toString() : qsTr("The decision was not recorded. Check: horneroctl assistant status");
            if (ok) {
                const runId = AssistantRun.runId;
                // The original stream may still be open (the gateway
                // keeps it while waiting): then it simply continues.
                // Only a closed stream needs a follow-up events call.
                const streamLive = askProcess.running;
                root.decisions = root.decisions.concat([{
                            "kind": root.decisionKind,
                            "denied": root.decisionDenied,
                            "detail": root.decisionDetail,
                            "ts": Date.now()
                        }]).slice(-30);
                AssistantRun.decided(true, root.decisionDenied, message);
                CompanionStore.say(message, 9000);
                // The run continues after a decision; follow its events.
                if (runId !== "" && !streamLive)
                    root.followEvents(runId);
            } else {
                AssistantRun.decided(false, false, message);
                CompanionStore.say(message, 9000);
            }
        }
    }

    function followEvents(runId: string): void {
        if (askProcess.running || runId === "")
            return;
        root.askSeq = AssistantRun.begin(CompanionStore.chatMode, true);
        // begin() clears the run; keep the id we are following.
        AssistantRun.feed(root.askSeq, JSON.stringify({
            "type": "run",
            "text": runId
        }));
        askProcess.command = ["horneroctl", "assistant", "events", runId, "--json", "--stream"];
        askProcess.running = true;
    }

    Process {
        id: askProcess

        stdout: SplitParser {
            onRead: data => {
                AssistantRun.feed(root.askSeq, data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            const seq = root.askSeq;
            AssistantRun.exited(seq, exitCode);
            if (root.recordPath !== "" && !root.recording)
                root.discardRecording();
            root.settleRun();
        }
    }

    // Presents the settled run: history entry + one short bubble. The
    // state itself already lives in AssistantRun; this only writes
    // the shell-side conversation cache.
    function settleRun(): void {
        const run = AssistantRun.run;
        const text = run.text;
        const trace = AssistantRun.traceLines();
        if (run.phase === "completed") {
            if (text !== "") {
                root.pushHistoryTraced("assistant", text, trace);
                CompanionStore.say(text, 12000);
            }
        } else if (run.phase === "awaiting-approval" || run.phase === "awaiting-clarification") {
            if (text !== "")
                root.pushHistoryTraced("assistant", text, trace);
            const detail = run.pending ? run.pending.detail : "";
            root.pushHistory("system", detail !== "" ? detail : AssistantCopy.t(run.phase === "awaiting-approval" ? "status.awaiting-approval" : "status.awaiting-clarification", root.lang));
        } else if (run.phase === "blocked") {
            root.pushHistory("system", run.error !== "" ? run.error : AssistantCopy.t("quick.blocked", root.lang));
            CompanionStore.say(run.error, 9000);
        } else if (run.phase === "failed") {
            root.pushHistory("system", run.error);
            CompanionStore.say(run.error, 9000);
        } else if (run.phase === "disconnected") {
            if (text !== "")
                root.pushHistoryTraced("assistant", text + " ⚠", trace);
            root.pushHistory("system", AssistantCopy.t(text !== "" ? "error.interrupted" : "error.no-answer", root.lang));
            root.refreshStatus();
        }
    }
}
