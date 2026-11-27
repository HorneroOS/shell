pragma Singleton

import "clipboard.js" as Model
import Quickshell
import Quickshell.Io
import QtQuick

// In-memory Wayland clipboard history and safe wl-copy writer
// (HorneroOS/shell#737). Subprocesses live exclusively in this service
// (ADR-002); UI modules never spawn clipboard processes directly.
// Password-manager MIMEs (e.g. x-kde-passwordManagerHint) and the initial
// startup burst are skipped, and history stays strictly in memory.
Singleton {
    id: root

    property var entries: []
    property int nextId: 1
    property real startedAtMs: 0
    property bool active: false
    property var pendingMimeTypes: []

    readonly property bool hasWaylandDisplay: (Quickshell.env("WAYLAND_DISPLAY") ?? "") !== ""
        || (Quickshell.env("NIRI_SOCKET") ?? "") !== ""
        || (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""

    function query(text: string): var {
        return Model.filterEntries(root.entries, text);
    }

    function formatMeta(entry: var): string {
        if (!entry)
            return "";
        const chars = Number(entry.chars) || 0;
        const lines = Number(entry.lines) || 1;
        if (lines > 1)
            return qsTr("%1 lines · %2 chars").arg(lines).arg(chars);
        return qsTr("%1 chars").arg(chars);
    }

    function recordEntry(text: string, mime: string, mimeTypes: var): bool {
        if (mimeTypes !== undefined && Model.shouldSkipMimeTypes(mimeTypes))
            return false;
        const entry = Model.normalizeEntry(text, mime, Date.now(), root.nextId);
        if (!entry)
            return false;
        root.nextId += 1;
        root.entries = Model.upsertEntry(root.entries, entry, Model.MAX_ENTRIES);
        return true;
    }

    function removeEntry(id: int): void {
        root.entries = root.entries.filter(e => e && e.id !== id);
    }

    function clear(): void {
        root.entries = [];
    }

    // Write clipboard text via wl-copy stdin so payloads such as "--clear"
    // can never be interpreted as CLI flags.
    function copyText(text: string): void {
        if (typeof text !== "string" || text.length === 0)
            return;
        copyProc.pending = text;
        if (!copyProc.running)
            copyProc.begin();
    }

    function handleWatchEvent(): void {
        if (Model.isInitialBurst(Date.now(), root.startedAtMs))
            return;
        if (!typesProc.running && !readProc.running) {
            typesProc.out = "";
            typesProc.running = true;
        }
    }

    Component.onCompleted: {
        root.startedAtMs = Date.now();
        if (root.hasWaylandDisplay) {
            watchProc.running = true;
            root.active = true;
        }
    }

    Process {
        id: watchProc

        running: false
        command: ["wl-paste", "--watch", "echo", "changed"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "")
                    root.handleWatchEvent();
            }
        }
        onExited: root.active = false
    }

    Process {
        id: typesProc

        property string out: ""

        running: false
        command: ["wl-paste", "--list-types"]
        stdout: StdioCollector {
            onStreamFinished: typesProc.out = text
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            const list = Model.normalizeMimeList(typesProc.out);
            if (Model.shouldSkipMimeTypes(list))
                return;
            root.pendingMimeTypes = list;
            readProc.out = "";
            readProc.running = true;
        }
    }

    Process {
        id: readProc

        property string out: ""

        running: false
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: readProc.out = text
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            const mime = Model.primaryTextMime(root.pendingMimeTypes);
            root.recordEntry(readProc.out, mime, root.pendingMimeTypes);
            root.pendingMimeTypes = [];
        }
    }

    Process {
        id: copyProc

        property string pending: ""
        property string sending: ""

        function begin(): void {
            copyProc.sending = copyProc.pending;
            copyProc.pending = "";
            copyProc.stdinEnabled = true;
            copyProc.running = true;
        }

        running: false
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: {
            copyProc.write(copyProc.sending);
            copyProc.sending = "";
            copyProc.stdinEnabled = false;
        }
        onRunningChanged: {
            if (!copyProc.running && copyProc.pending !== "")
                copyProc.begin();
        }
    }
}
