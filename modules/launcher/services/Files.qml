pragma Singleton

import "filesearch.js" as FileSearch
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// File provider logic (shell#250 slice 2, registry migration):
// bounded, privacy-aware, on-demand search over the XDG user
// dirs plus the home top level. No indexing daemon and no
// background crawling: `find` runs only for a debounced query,
// a new query cancels the previous run, and stale generations
// never publish. All bounds/exclusions/ranking live in the
// pure filesearch.js; this singleton only owns the processes.
// Missing or unreadable roots degrade to no rows for that root,
// never to an error that breaks the launcher.
Singleton {
    id: root

    property var results: []
    property string status: ""
    property bool busy: false

    property int generation: 0
    property string requestedQuery: ""
    property string activeQuery: ""
    property int pendingRuns: 0
    property bool userDirsDone: false
    property bool homeDone: false

    readonly property int maxResults: FileSearch.MAX_RESULTS
    readonly property int maxDepth: FileSearch.MAX_DEPTH

    function roots(): var {
        return FileSearch.userRoots(Paths.home, {
            "XDG_DOCUMENTS_DIR": Quickshell.env("XDG_DOCUMENTS_DIR") ?? "",
            "XDG_DOWNLOAD_DIR": Quickshell.env("XDG_DOWNLOAD_DIR") ?? "",
            "XDG_DESKTOP_DIR": Quickshell.env("XDG_DESKTOP_DIR") ?? "",
            "XDG_PICTURES_DIR": Quickshell.env("XDG_PICTURES_DIR") ?? "",
            "XDG_MUSIC_DIR": Quickshell.env("XDG_MUSIC_DIR") ?? "",
            "XDG_VIDEOS_DIR": Quickshell.env("XDG_VIDEOS_DIR") ?? ""
        });
    }

    // Called by the registry query on every model evaluation.
    // Idempotent per query text: repeated evaluations with the
    // same text return the current snapshot and never restart
    // the debounce; a changed text cancels and reschedules.
    function requestSearch(text: string): void {
        const q = (text ?? "").trim();
        if (q === root.requestedQuery)
            return;
        root.requestedQuery = q;
        root.invalidate();
        if (q.length < FileSearch.MIN_QUERY_LENGTH) {
            root.activeQuery = "";
            root.results = [];
            root.status = qsTr("Type at least 2 characters");
            return;
        }
        root.status = qsTr("Searching…");
        debounce.restart();
    }

    // Re-run the currently requested query when the file route is
    // entered again. This makes files created while the launcher was
    // closed discoverable without adding a filesystem watcher daemon.
    function refresh(): void {
        if (root.requestedQuery.length < FileSearch.MIN_QUERY_LENGTH)
            return;
        root.invalidate();
        root.status = qsTr("Searching…");
        debounce.restart();
    }

    // Internal invalidation: bumps the generation and stops work
    // without forgetting which query the route is currently serving.
    function invalidate(): void {
        root.generation++;
        debounce.stop();
        searchTimeout.stop();
        userDirsProc.running = false;
        homeProc.running = false;
        root.pendingRuns = 0;
        root.userDirsDone = false;
        root.homeDone = false;
        root.busy = false;
    }

    // Public cancellation also forgets the query, so entering the
    // same text after leaving/closing always performs a fresh search.
    function cancel(): void {
        root.invalidate();
        root.requestedQuery = "";
        root.activeQuery = "";
    }

    function startSearch(): void {
        const q = root.requestedQuery;
        if (q.length < FileSearch.MIN_QUERY_LENGTH)
            return;
        root.invalidate();
        root.activeQuery = q;
        root.status = qsTr("Searching…");
        root.busy = true;
        const allRoots = root.roots();
        const userRoots = allRoots.filter(r => r.maxDepth > FileSearch.HOME_MAX_DEPTH);
        const homeRoots = allRoots.filter(r => r.maxDepth <= FileSearch.HOME_MAX_DEPTH);
        root.pendingRuns = 2;
        userDirsProc.gen = root.generation;
        userDirsProc.out = "";
        userDirsProc.command = FileSearch.buildFindArgs(userRoots, q, FileSearch.MAX_DEPTH);
        userDirsProc.running = true;
        homeProc.gen = root.generation;
        homeProc.out = "";
        homeProc.command = FileSearch.buildFindArgs(homeRoots, q, FileSearch.HOME_MAX_DEPTH);
        homeProc.running = true;
        searchTimeout.restart();
    }

    function publishResults(complete: bool): void {
        let entries = [];
        if (root.userDirsDone)
            entries = [...entries, ...FileSearch.parseFindOutput(userDirsProc.out)];
        if (root.homeDone)
            entries = [...entries, ...FileSearch.parseFindOutput(homeProc.out)];
        root.results = FileSearch.rankResults(entries, root.activeQuery, root.roots());
        if (complete) {
            userDirsProc.out = "";
            homeProc.out = "";
            root.status = root.results.length === 0 ? qsTr("No files found") : "";
        } else {
            root.status = qsTr("Searching…");
        }
    }

    function finishRun(gen: int, userDirs: bool): void {
        if (gen !== root.generation)
            return;
        if (userDirs) {
            if (root.userDirsDone)
                return;
            root.userDirsDone = true;
        } else {
            if (root.homeDone)
                return;
            root.homeDone = true;
        }
        root.pendingRuns = (root.userDirsDone ? 0 : 1) + (root.homeDone ? 0 : 1);
        const complete = root.userDirsDone && root.homeDone;
        if (complete) {
            searchTimeout.stop();
            root.busy = false;
        }
        root.publishResults(complete);
    }

    function timeoutSearch(): void {
        if (!root.busy)
            return;
        userDirsProc.running = false;
        homeProc.running = false;
        root.userDirsDone = true;
        root.homeDone = true;
        root.pendingRuns = 0;
        root.busy = false;
        root.publishResults(true);
        root.status = root.results.length === 0 ? qsTr("Search timed out") : qsTr("Search timed out — partial results");
    }

    function appendOutput(proc: var, data: string): void {
        const room = FileSearch.MAX_RAW_OUTPUT_CHARS - proc.out.length;
        if (room <= 0) {
            proc.running = false;
            return;
        }
        proc.out += data.substring(0, room) + "\n";
        if (data.length >= room)
            proc.running = false;
    }

    function activate(result: var): void {
        const payload = result?.payload ?? result;
        const path = payload?.path ?? "";
        if (typeof path === "string" && path.length > 0)
            Quickshell.execDetached(["xdg-open", path]);
    }

    Timer {
        id: debounce

        interval: FileSearch.DEBOUNCE_MS
        onTriggered: root.startSearch()
    }

    Timer {
        id: searchTimeout

        interval: FileSearch.SEARCH_TIMEOUT_MS
        onTriggered: root.timeoutSearch()
    }

    Process {
        id: userDirsProc

        property int gen: 0
        property string out: ""

        stdout: SplitParser {
            onRead: data => root.appendOutput(userDirsProc, data)
        }
        onExited: (exitCode, exitStatus) => root.finishRun(userDirsProc.gen, true)
    }

    Process {
        id: homeProc

        property int gen: 0
        property string out: ""

        stdout: SplitParser {
            onRead: data => root.appendOutput(homeProc, data)
        }
        onExited: (exitCode, exitStatus) => root.finishRun(homeProc.gen, false)
    }
}
