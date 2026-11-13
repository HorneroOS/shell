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
        root.cancel();
        if (q.length < FileSearch.MIN_QUERY_LENGTH) {
            root.results = [];
            root.status = q.length === 0 ? "" : qsTr("Type at least 2 characters");
            return;
        }
        root.status = qsTr("Searching…");
        debounce.restart();
    }

    function cancel(): void {
        root.generation++;
        debounce.stop();
        userDirsProc.running = false;
        homeProc.running = false;
        root.pendingRuns = 0;
        root.busy = false;
    }

    function startSearch(): void {
        const q = root.requestedQuery;
        if (q.length < FileSearch.MIN_QUERY_LENGTH)
            return;
        root.cancel();
        root.activeQuery = q;
        root.results = [];
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
    }

    function finishRun(gen: int): void {
        if (gen !== root.generation)
            return;
        root.pendingRuns--;
        if (root.pendingRuns > 0)
            return;
        root.busy = false;
        const entries = [...FileSearch.parseFindOutput(userDirsProc.out), ...FileSearch.parseFindOutput(homeProc.out)];
        userDirsProc.out = "";
        homeProc.out = "";
        root.results = FileSearch.rankResults(entries, root.activeQuery, root.roots());
        root.status = root.results.length === 0 ? qsTr("No files found") : "";
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

    Process {
        id: userDirsProc

        property int gen: 0
        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                userDirsProc.out += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => root.finishRun(userDirsProc.gen)
    }

    Process {
        id: homeProc

        property int gen: 0
        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                homeProc.out += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => root.finishRun(homeProc.gen)
    }
}
