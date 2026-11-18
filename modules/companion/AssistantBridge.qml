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
    // "Stream answers live" off: the text appears once, when done.
    readonly property string streamText: CompanionStore.chatStreaming && (AssistantRun.active || AssistantRun.pendingDecision) ? AssistantRun.answerText : ""
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
        sessionActionProc.command = ["horneroctl", "assistant", "sessions", "new", "--json", "--", title];
        sessionActionProc.running = true;
        root.clearHistory();
    }

    function useChatSession(id: string): void {
        if (id === root.currentSession)
            return;
        sessionActionProc.out = "";
        sessionActionProc.command = ["horneroctl", "assistant", "sessions", "use", "--json", "--", id];
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

    // The text goes to the writer on STDIN, never through the shell
    // command line (no quoting, no injection, no argv size limit).
    // `lastSavedHistory` only advances after a successful write, so a
    // failed write is retried on the next change. Writes are
    // serialised: a change during a write is saved right after it.
    property string wantedHistory: ""
    property bool historyWriting: false

    function saveHistory(): void {
        // Retention 0 ("off") keeps the conversation in memory only.
        const text = CompanionStore.chatHistoryLimit === 0 ? "[]" : JSON.stringify(root.history);
        root.wantedHistory = text;
        root.flushHistory();
    }

    function flushHistory(): void {
        if (root.historyWriting || root.wantedHistory === root.lastSavedHistory)
            return;
        root.historyWriting = true;
        root.writingHistory = root.wantedHistory;
        const path = root.historyPath;
        historyWriter.command = ["sh", "-c", "umask 077; d=\"$(dirname \"$1\")\"; mkdir -p -m 700 \"$d\" && chmod 700 \"$d\" && tmp=\"$(mktemp \"$d/.chat.XXXXXX\")\" && cat > \"$tmp\" && mv -f \"$tmp\" \"$1\"", "sh", path];
        historyWriter.running = true;
    }

    property string writingHistory: ""

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

    // The panel's Send: the panel's mode and the files the user attached
    // in the panel. Every other path (IPC, hand-off, retry, voice) calls
    // askWith with its own explicit mode and attachment list.
    function ask(text: string): void {
        const files = root.attachments.slice();
        root.attachments = [];
        root.askWith(text, CompanionStore.chatMode, files);
    }

    // `mode` and `files` are explicit per call: external entry points
    // (IPC) always pass "ask" and no files, so nothing outside the panel
    // can start an agent run or send a file the user queued.
    function askWith(text: string, mode: string, files: var): void {
        const prompt = (text ?? "").toString().trim();
        const sentAttachments = Array.isArray(files) ? files.map(f => f.toString()) : [];
        if (prompt === "" && sentAttachments.length === 0)
            return;
        if (root.busy || AssistantRun.pendingDecision) {
            CompanionStore.say(AssistantCopy.t("status.running", root.lang), 4000);
            return;
        }
        const runMode = ["ask", "agent", "chat"].includes(mode) ? mode : "ask";
        root.lastPrompt = prompt;
        const shown = prompt === "" ? qsTr("(attachment)") : prompt;
        root.pushHistory("user", sentAttachments.length > 0 ? `${shown} 📎 ${sentAttachments.length}` : shown);
        root.noteArtifacts(sentAttachments);
        root.askSeq = AssistantRun.begin(runMode, false);
        root.clearPendingSnapshot();
        // Options first, then `--` and the text: a prompt that starts
        // with a dash is data, never a flag.
        let cmd = ["horneroctl", "assistant", "ask", "--json", "--stream", "--mode", runMode];
        if (root.currentSession !== "")
            cmd = cmd.concat(["--session", root.currentSession]);
        for (const p of sentAttachments)
            cmd = cmd.concat(["--attach", p.toString()]);
        cmd = cmd.concat(["--", prompt === "" ? qsTr("Describe and answer based on the attached file(s).") : prompt]);
        askProcess.command = cmd;
        askProcess.running = true;
    }

    // Text staged for the panel's input by an external entry point
    // (hand-off from the quick ask). Never sent by itself.
    property string draft: ""

    // Hand-off from Javi Radio or the launcher's `>ai` row (the user
    // pressed "Open the Workbench"). `payload` is InlineAsk.handoffInfo():
    // the question and the exact request the read-only quick run ran
    // into. That run was `--mode ask`, so horneroctl already denied its
    // approval (or the quick ask stopped it) and will refuse to approve
    // it; it is recorded for display only (AssistantRun.handoffRecord),
    // never as a pending decision. A live run or a pending decision is
    // never replaced. The question is not sent: continueHandoff() is the
    // user's explicit "run it as an Agent" action.
    function notePayload(payload): void {
        if (!payload || root.busy || AssistantRun.pendingDecision)
            return;
        AssistantRun.handoff(payload);
    }

    // The user pressed "Run as Agent" on the hand-off card: a NEW Agent
    // run of the same question, started from the Workbench UI only (never
    // from IPC). Its approvals arrive on the normal approval card, bound to
    // the exact request (`--request id@gen`); nothing is pre-approved.
    function continueHandoff(): void {
        const rec = AssistantRun.handoffRecord;
        if (!rec || root.busy || AssistantRun.pendingDecision)
            return;
        root.askWith(rec.question, "agent", []);
    }

    // Put the handed-off question in the input instead (edit before
    // sending, or send in another mode).
    function editHandoff(): void {
        const rec = AssistantRun.handoffRecord;
        if (!rec)
            return;
        root.draft = rec.question;
        AssistantRun.reset();
    }

    // The open panel already shows every outcome; a speech bubble would
    // grow the companion window past the screen. Bubbles are for when
    // the conversation is closed.
    function sayIfClosed(text: string, ms: int): void {
        if (!root.chatOpen)
            CompanionStore.say(text, ms);
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
                // Via stdin: the answer never appears in an argv (visible
                // to every process of the user in /proc).
                root.copyText = root.history[i].text.toString();
                copyProcess.running = false;
                copyProcess.command = ["wl-copy"];
                copyProcess.running = true;
                CompanionStore.say("Answer copied.", 3000);
                return;
            }
        }
        CompanionStore.say("Nothing to copy yet.", 3000);
    }

    property string copyText: ""

    // Retry re-sends the text only (no attachments), in the mode the
    // panel shows now.
    function retryLast(): void {
        if (root.lastPrompt !== "" && !root.busy)
            root.askWith(root.lastPrompt, CompanionStore.chatMode, []);
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
    // fixed: two minutes is a privacy cap on one recording (an
    // ambient-mic backstop), not a taste setting; it is exposed as
    // `recordMaxSeconds` for tests only.
    property int recordSeconds: 0
    readonly property int recordMaxSeconds: 120
    // Voice files live in a private (0700) cache dir, are created
    // 0600, and are deleted in every exit path: discard, run end,
    // shell shutdown and a sweep of stale clips at startup.
    readonly property string voiceDir: `${Quickshell.cacheDir}/javi-voice`
    property var voiceFiles: []

    function startRecording(): void {
        if (root.recording || root.busy)
            return;
        const rnd = Math.floor(Math.random() * 0xffffffff).toString(16);
        root.recordPath = `${root.voiceDir}/javi-voice-${Date.now()}-${rnd}.wav`;
        root.voiceFiles = root.voiceFiles.concat([root.recordPath]);
        recordProcess.command = ["sh", "-c", "umask 077; mkdir -p -m 700 \"$1\" && chmod 700 \"$1\" && exec pw-record --rate 16000 --channels 1 \"$2\"", "sh", root.voiceDir, root.recordPath];
        recordProcess.running = true;
        root.recordSeconds = 0;
        root.recording = true;
        CompanionStore.requestState("listening");
    }

    // send=true: attach and send. send=false with keep=false: discard.
    // keep=true (auto-stop): attach but do NOT send and do NOT delete,
    // so a long recording is never lost silently.
    function stopRecording(send: bool, keep: bool): void {
        if (!root.recording)
            return;
        root.recording = false;
        recordProcess.running = false;
        CompanionStore.requestState("idle");
        if (send && root.recordPath !== "") {
            // A spoken message is always a read-only Ask run: speech is
            // not a reviewed, typed instruction, so it never acts.
            root.askWith(qsTr("Transcribe the attached audio and treat the transcription as my message. Answer it."), "ask", [root.recordPath]);
        } else if (keep === true && root.recordPath !== "") {
            // Auto-stop: the clip is kept for the user to confirm
            // (Attach) or drop; it is never attached on its own.
            root.heldClip = root.recordPath;
        } else {
            root.discardRecording();
        }
    }

    // A clip held after the 2-minute auto-stop, waiting for the user.
    property string heldClip: ""

    function attachHeldClip(): void {
        if (root.heldClip === "")
            return;
        root.addAttachment(root.heldClip);
        root.heldClip = "";
    }

    function dropHeldClip(): void {
        if (root.heldClip === "")
            return;
        root.removeVoiceFile(root.heldClip);
        root.heldClip = "";
    }

    function discardRecording(): void {
        if (root.recordPath === "")
            return;
        root.removeVoiceFile(root.recordPath);
        root.recordPath = "";
    }

    function removeVoiceFile(path: string): void {
        if (!path.startsWith(root.voiceDir + "/"))
            return;
        Quickshell.execDetached(["rm", "-f", "--", path]);
        root.voiceFiles = root.voiceFiles.filter(p => p !== path);
        root.attachments = root.attachments.filter(p => p !== path);
    }

    function removeAllVoiceFiles(): void {
        for (const p of root.voiceFiles.slice())
            root.removeVoiceFile(p);
    }

    // Stale clips from a crashed session (and the pre-0700 location).
    function sweepVoiceFiles(): void {
        sweepProcess.command = ["sh", "-c", "find \"$1\" -maxdepth 1 -name 'javi-voice-*.wav' -mmin +2 -delete 2>/dev/null; find \"$2\" -maxdepth 1 -name 'javi-voice-*.wav' -mmin +2 -delete 2>/dev/null; true", "sh", root.voiceDir, Quickshell.cacheDir];
        sweepProcess.running = true;
    }

    Process {
        id: sweepProcess
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: {
            root.recordSeconds += 1;
            if (root.recordSeconds >= root.recordMaxSeconds) {
                root.stopRecording(false, true);
                CompanionStore.say(AssistantCopy.t("mic.auto-stopped", root.lang), 6000);
            }
        }
    }

    // Approval / clarification UX: decisions are always explicit user
    // actions on a specific run. Nothing here answers Hermes on its
    // own, there is no "approve all", and `approve` is the single
    // action `once` on the backend.
    // `shownRequest` is the request id the card displayed when the user
    // clicked: the decision is refused unless it is still the one
    // waiting.
    function approve(runId: string, decision: string, shownRequest: string): void {
        const id = (runId ?? "").toString().trim();
        const choice = (decision ?? "").toString().trim();
        const shown = (shownRequest ?? "").toString();
        if (!AssistantRun.isValidRunId(id) || (choice !== "approve" && choice !== "deny")) {
            CompanionStore.say("I need a valid run id and an approve or deny decision.", 6000);
            return;
        }
        if (root.decisionBusy)
            return;
        // The decision must name the run AND the exact request that
        // is waiting: a stale card cannot decide another request.
        const pend = AssistantRun.pending;
        if (AssistantRun.phase !== "awaiting-approval" || !pend || pend.kind !== "approval" || pend.runId !== id || pend.requestId !== shown) {
            CompanionStore.say(qsTr("That request is no longer waiting."), 5000);
            return;
        }
        if (choice === "approve" && pend.mode !== "agent") {
            // Only an Agent run may be approved (horneroctl refuses the
            // rest too); Ask/Chat requests can only be denied.
            CompanionStore.say(qsTr("Only an Agent run can be allowed. You can deny it."), 6000);
            return;
        }
        if (choice === "approve" && (pend.requestId === "" || pend.truncated)) {
            // Allow needs a request id to bind to and the whole text on
            // screen; Deny is always possible.
            CompanionStore.say(qsTr("This request cannot be allowed from here. You can deny it."), 6000);
            return;
        }
        root.decisionBusy = true;
        root.decisionBuffer = "";
        root.decisionKind = "approval";
        root.decisionDenied = choice === "deny";
        root.decisionDetail = pend.detail;
        root.decisionRun = id;
        root.decisionRequest = pend.requestId;
        let cmd = ["horneroctl", "assistant", "approve", id, choice, "--json"];
        if (pend.requestId !== "")
            cmd = cmd.concat(["--request", pend.requestId]);
        decisionProcess.command = cmd;
        decisionProcess.running = true;
    }

    // `shownDetail` is the question the card displayed when the user
    // answered: an answer is never sent to a different question.
    function clarify(runId: string, answer: string, shownDetail: string): void {
        const id = (runId ?? "").toString().trim();
        const text = (answer ?? "").toString().trim();
        if (!AssistantRun.isValidRunId(id) || text === "" || root.decisionBusy)
            return;
        const pend = AssistantRun.pending;
        if (AssistantRun.phase !== "awaiting-clarification" || !pend || pend.kind !== "clarify" || pend.runId !== id || pend.detail !== (shownDetail ?? "").toString()) {
            CompanionStore.say(qsTr("That question is no longer waiting."), 5000);
            return;
        }
        root.decisionBusy = true;
        root.decisionBuffer = "";
        root.decisionKind = "clarify";
        root.decisionDenied = false;
        root.decisionDetail = pend.detail;
        root.decisionRun = id;
        root.decisionRequest = "";
        decisionProcess.command = ["horneroctl", "assistant", "clarify", id, "--json", "--", text];
        decisionProcess.running = true;
    }

    property string decisionRun: ""
    property string decisionRequest: ""
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
        // A decision is on its way to the gateway: stopping now would
        // race it (the action may already be approved). Wait for it.
        if (root.decisionBusy) {
            CompanionStore.say(qsTr("A decision is being sent; stop once it is recorded."), 5000);
            return;
        }
        const id = AssistantRun.runId;
        const partial = AssistantRun.answerText;
        const wasPending = AssistantRun.pendingDecision;
        AssistantRun.cancel();
        root.clearPendingSnapshot();
        if (partial !== "" && !wasPending)
            root.pushHistory("assistant", partial + " ⏹");
        if (AssistantRun.isValidRunId(id)) {
            root.stopRunOnGateway(id);
            root.sayIfClosed(qsTr("Stopped, including the Hermes run."), 5000);
        } else if (askProcess.running) {
            // The gateway has not told us the run id yet. Killing the
            // process now would orphan a run that is about to start:
            // keep it until the id arrives (the `run` frame), stop the
            // run, then end it. A deadline kills it and says so.
            root.stopWhenKnown = true;
            stopDeadline.restart();
            root.sayIfClosed(qsTr("Stopping as soon as the run id is known…"), 5000);
            return;
        } else {
            AssistantRun.exited(AssistantRun.run.seq, 0);
            return;
        }
        if (askProcess.running)
            askProcess.running = false;
        else
            AssistantRun.exited(AssistantRun.run.seq, 0);
    }

    // The id is captured into the command at the moment of the call.
    property bool stopWhenKnown: false
    property string stoppingRun: ""

    function stopRunOnGateway(id: string): void {
        if (!AssistantRun.isValidRunId(id))
            return;
        root.stoppingRun = id;
        stopProcess.running = false;
        stopProcess.command = ["horneroctl", "assistant", "stop", id, "--json"];
        stopProcess.running = true;
    }

    Connections {
        target: AssistantRun

        function onRunIdChanged(): void {
            if (root.stopWhenKnown && AssistantRun.isValidRunId(AssistantRun.runId)) {
                root.stopWhenKnown = false;
                stopDeadline.stop();
                root.stopRunOnGateway(AssistantRun.runId);
                if (askProcess.running)
                    askProcess.running = false;
                root.sayIfClosed(qsTr("Stopped, including the Hermes run."), 5000);
            }
        }
    }

    Timer {
        id: stopDeadline

        // fixed: how long a cancel waits for the run id before giving
        // up (a safety deadline, not a preference).
        interval: 8000
        onTriggered: {
            if (root.stopWhenKnown) {
                root.stopWhenKnown = false;
                askProcess.running = false;
                root.sayIfClosed(qsTr("Stopped locally; the run may still be going on the gateway (its id was never known)."), 8000);
            }
        }
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
        root.writeSnapshot(JSON.stringify({
            "runId": pend.runId,
            "kind": pend.kind,
            "detail": pend.detail
        }));
    }

    function clearPendingSnapshot(): void {
        root.writeSnapshot("");
    }

    // One writer at a time, last request wins: `wantedSnapshot` is what
    // the file should hold ("" = no file). A request made while a write
    // runs is applied when it exits, never by restarting the process
    // mid-write. The text goes through stdin (never argv, which other
    // processes of the user can read), into a private dir/file.
    property string wantedSnapshot: ""
    property string writingSnapshot: ""
    property bool snapshotDirty: false

    function writeSnapshot(text: string): void {
        root.wantedSnapshot = text;
        root.snapshotDirty = true;
        if (!pendingWriter.running)
            root.flushSnapshot();
    }

    function flushSnapshot(): void {
        if (!root.snapshotDirty || pendingWriter.running)
            return;
        root.snapshotDirty = false;
        root.writingSnapshot = root.wantedSnapshot;
        pendingWriter.stdinEnabled = true;
        pendingWriter.command = root.writingSnapshot === "" ? ["rm", "-f", "--", root.pendingPath] : ["sh", "-c", "umask 077; d=\"$(dirname \"$1\")\"; mkdir -p -m 700 \"$d\" && chmod 700 \"$d\" && cat > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"", "sh", root.pendingPath];
        pendingWriter.running = true;
    }

    function verifyRestoredRequest(snap: var): void {
        if (!snap || !AssistantRun.isValidRunId((snap.runId ?? "").toString()) || root.busy) {
            // A malformed snapshot is never acted on; drop it.
            root.clearPendingSnapshot();
            return;
        }
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
        root.sweepVoiceFiles();
    }

    // Shell exit: do not leave an Ask/Agent run orphaned on the
    // gateway, and remove any voice clip.
    Component.onDestruction: {
        const id = AssistantRun.runId;
        if ((root.busy || AssistantRun.pendingDecision) && AssistantRun.isValidRunId(id))
            Quickshell.execDetached(["horneroctl", "assistant", "stop", id, "--json"]);
        for (const p of root.voiceFiles)
            if (p.startsWith(root.voiceDir + "/"))
                Quickshell.execDetached(["rm", "-f", "--", p]);
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

        stdinEnabled: true
        onStarted: {
            if (root.writingSnapshot !== "")
                pendingWriter.write(root.writingSnapshot);
            pendingWriter.stdinEnabled = false;
        }
        onExited: (exitCode, exitStatus) => root.flushSnapshot()
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
            // Not pending anymore (decided, finished, expired or not
            // found): drop the snapshot and show nothing stale.
            if (!AssistantRun.pending) {
                root.clearPendingSnapshot();
                AssistantRun.reset();
            }
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
                        const m = line.match(new RegExp(id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + " — (.*) \\(since"));
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
        modelSetProc.command = ["horneroctl", "assistant", "model", "set", "--yes", "--json", "--", m];
        modelSetProc.running = true;
    }

    Process {
        id: modelSetProc

        onExited: (exitCode, exitStatus) => root.refreshSessions()
    }

    Process {
        id: historyWriter

        stdinEnabled: true
        onStarted: {
            historyWriter.write(root.writingHistory);
            historyWriter.stdinEnabled = false;
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.lastSavedHistory = root.writingHistory;
            root.historyWriting = false;
            historyWriter.stdinEnabled = true;
            // A change that arrived during the write (or a failed
            // write on the next change) is flushed by the next call;
            // flush now only for a newer text, never in a failure loop.
            if (exitCode === 0)
                root.flushHistory();
        }
    }

    Process {
        id: copyProcess

        stdinEnabled: true
        onStarted: {
            copyProcess.write(root.copyText);
            copyProcess.stdinEnabled = false;
        }
        onExited: (exitCode, exitStatus) => {
            root.copyText = "";
            copyProcess.stdinEnabled = true;
        }
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
    // fixed: 15 s is a gentle reconnect probe (one status call, only
    // while the panel is open and not connected); it is a courtesy,
    // not a visible preference, and the Reconnect button is immediate.
    Timer {
        interval: 15000
        repeat: true
        running: root.chatOpen && AssistantRun.gateway.connection !== "connected" && AssistantRun.gateway.connection !== "disabled"
        onTriggered: root.refreshStatus()
    }

    Process {
        id: stopProcess

        // A stop that the gateway did not accept is reported, never
        // silently assumed to have worked.
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                CompanionStore.say(qsTr("The stop request for %1 was not accepted. It may still be running.").arg(root.stoppingRun), 9000);
        }
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
                const runId = root.decisionRun;
                // The original stream may still be open (the gateway
                // keeps it while waiting): then it simply continues.
                // Only a closed stream needs a follow-up events call.
                const streamLive = askProcess.running;
                // The stream may have finished on its own between the
                // click and this result (the gateway resumed the run
                // the moment it was decided); following then would
                // replay the whole answer a second time.
                const needFollow = !streamLive && AssistantRun.pendingDecision;
                root.decisions = root.decisions.concat([{
                            "kind": root.decisionKind,
                            "denied": root.decisionDenied,
                            "detail": root.decisionDetail,
                            "ts": Date.now()
                        }]).slice(-30);
                AssistantRun.decided(true, root.decisionDenied, message, root.decisionRun, root.decisionRequest, root.decisionDetail);
                root.sayIfClosed(message, 9000);
                // The run continues after a decision; follow its events
                // only when its stream is gone and it is still unsettled.
                if (runId !== "" && needFollow)
                    root.followEvents(runId);
            } else {
                AssistantRun.decided(false, false, message, root.decisionRun, root.decisionRequest, root.decisionDetail);
                root.sayIfClosed(message, 9000);
            }
        }
    }

    function followEvents(runId: string): void {
        if (askProcess.running || !AssistantRun.isValidRunId(runId))
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
            // The clips of this message are no longer needed.
            if (!root.recording)
                root.removeAllVoiceFiles();
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
                // The panel already shows the answer; the bubble is
                // only for when the conversation is closed.
                root.sayIfClosed(text, 12000);
            }
        } else if (run.phase === "awaiting-approval" || run.phase === "awaiting-clarification") {
            if (text !== "")
                root.pushHistoryTraced("assistant", text, trace);
            const detail = run.pending ? run.pending.detail : "";
            root.pushHistory("system", detail !== "" ? detail : AssistantCopy.t(run.phase === "awaiting-approval" ? "status.awaiting-approval" : "status.awaiting-clarification", root.lang));
        } else if (run.phase === "blocked") {
            root.pushHistory("system", run.error !== "" ? run.error : AssistantCopy.t("quick.blocked", root.lang));
            root.sayIfClosed(run.error, 9000);
        } else if (run.phase === "failed") {
            root.pushHistory("system", run.error);
            root.sayIfClosed(run.error, 9000);
        } else if (run.phase === "disconnected") {
            if (text !== "")
                root.pushHistoryTraced("assistant", text + " ⚠", trace);
            root.pushHistory("system", AssistantCopy.t(text !== "" ? "error.interrupted" : "error.no-answer", root.lang));
            root.refreshStatus();
        }
    }
}
