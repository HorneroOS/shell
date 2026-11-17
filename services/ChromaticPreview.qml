pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import "chromaticcli.js" as Cli

// Working state of the Control Center Chromatic section (RFC 0002 §13,
// contract §7.2).
//
// Preview: `hornero-chromatic generate` (one process in flight, newest
// request wins, 60 ms debounce) produces a candidate scheme that only
// ever lives in memory (`result`, and Signal.beginPreview when the user
// asks to see it on the live shell). Nothing here writes the live scheme,
// shell.json or any theme file.
//
// Apply: only `horneroctl appearance chromatic apply …`.
Singleton {
    id: root

    // Working copy of Config.appearance.chromatic (+ image path / seeds).
    property var request: Cli.normalise(Config.appearance.chromatic, Signal.themeMode)
    // Last good helper document: {scheme, analysis, inference, gates,
    // adjustments, fingerprint, request} or null.
    property var result: null
    readonly property bool busy: generateProc.running || debounce.running || _again
    // "" | engine-missing | source-unreadable | video-needs-ffmpeg | gates-unreachable | usage | internal | no-source
    property string errorCode: ""
    property string errorTitle: ""
    property string errorDetail: ""
    readonly property bool hasError: errorCode !== ""
    // True once a `version` probe answered; false means the helper is not
    // installed (the section then explains how to get it).
    property bool helperChecked: false
    property bool helperAvailable: false
    // The candidate is currently shown on the live shell.
    readonly property bool live: Signal.previewing
    property bool applying: false
    property string applyError: ""
    property string lastAppliedFingerprint: ""
    property string notice: ""
    // The fingerprint of the candidate differs from what is applied.
    readonly property bool dirty: result !== null && result.fingerprint !== Signal.chromatic?.fingerprint
    readonly property string helperPath: Quickshell.env("HORNERO_CHROMATIC_BIN") || "/usr/lib/hornero/hornero-chromatic"
    readonly property string wallpaper: Wallpapers.actualCurrent
    readonly property var perMode: ({
            "dark": {
                "variant": Config.appearance.chromatic.perMode.dark.variant
            },
            "light": {
                "variant": Config.appearance.chromatic.perMode.light.variant
            }
        })

    property bool _again: false
    property string _idleToken: ""

    signal savedPalettesChanged
    signal applied(string fingerprint)
    signal applyFailed(string code, string message)

    function probe(): void {
        if (!helperChecked) {
            probeProc.running = true;
            probeTimeout.restart();
        }
    }

    // Reset the working copy from the saved preferences.
    function reset(): void {
        request = Cli.normalise(Config.appearance.chromatic, Signal.themeMode);
        regenerate();
    }

    function setSource(kind: string, pathOrSeeds: var): void {
        const r = JSON.parse(JSON.stringify(request));
        r.source = Cli.SOURCES.indexOf(kind) >= 0 ? kind : "wallpaper";
        if (kind === "image")
            r.path = String(pathOrSeeds ?? "");
        else if (kind === "seed")
            r.seeds = Array.isArray(pathOrSeeds) ? pathOrSeeds : [String(pathOrSeeds)];
        request = Cli.normalise(r, Signal.themeMode);
        regenerate();
    }

    function set(key: string, value: var): void {
        const r = JSON.parse(JSON.stringify(request));
        r[key] = value;
        request = Cli.normalise(r, Signal.themeMode);
        regenerate();
    }

    function regenerate(): void {
        errorCode = "";
        debounce.restart();
    }

    function _start(): void {
        if (!helperAvailable && helperChecked) {
            _fail(Cli.describeFailure(0, "", true, false));
            return;
        }
        const args = Cli.helperArgs(request, wallpaper, perMode);
        if (!args) {
            result = null;
            errorCode = "no-source";
            errorTitle = request.source === "image" ? qsTr("Choose an image") : request.source === "seed" ? qsTr("Choose an accent colour") : qsTr("No wallpaper is set");
            errorDetail = qsTr("Chromatic needs a source to build a palette from.");
            return;
        }
        if (generateProc.running) {
            _again = true;
            return;
        }
        _again = false;
        generateProc.args = args;
        generateProc.video = request.source !== "seed" && request.source !== "house" && Cli.isVideoPath(request.source === "image" ? request.path : wallpaper);
        generateProc.running = true;
    }

    function _fail(f: var): void {
        result = null;
        errorCode = f.code;
        errorTitle = f.title;
        errorDetail = f.detail;
    }

    // Show the candidate on the live shell (memory only) or stop showing it.
    function previewLive(on: bool): void {
        if (on && result) {
            if (Signal.beginPreview(result.scheme))
                idleCancel.restart();
        } else {
            idleCancel.stop();
            Signal.cancelPreview();
        }
    }

    // Persist through horneroctl. `persist` false = one-off (no preferences).
    function apply(persist: bool): void {
        if (applying || !result)
            return;
        applyError = "";
        applying = true;
        applyProc.command = Cli.applyArgs(request, perMode, persist !== false);
        applyProc.running = true;
    }

    // Cancel: stop previewing and drop the working copy back to the saved
    // preferences. Writes nothing.
    function cancel(): void {
        idleCancel.stop();
        Signal.cancelPreview();
        applyError = "";
        notice = "";
        reset();
    }

    function saveAs(id: string, name: string): void {
        const sid = Cli.slug(id || name);
        if (!sid || !name.trim()) {
            notice = qsTr("Give the palette a name first.");
            return;
        }
        runCtl("save", Cli.saveArgs(sid, name.trim()), qsTr("Saved as “%1”.").arg(name.trim()));
    }

    function exportTo(path: string): void {
        if (!path.trim()) {
            notice = qsTr("Enter a file path to export to.");
            return;
        }
        runCtl("export", Cli.exportArgs(path.trim()), qsTr("Exported to %1.").arg(path.trim()));
    }

    function importFrom(path: string): void {
        if (!path.trim()) {
            notice = qsTr("Enter the file to import.");
            return;
        }
        runCtl("import", Cli.importArgs(path.trim(), ""), qsTr("Imported. It appears in the saved palettes."));
    }

    function rollback(): void {
        runCtl("rollback", Cli.rollbackArgs(), qsTr("Rolled back to the previous palette."));
    }

    function turnOff(): void {
        runCtl("off", Cli.offArgs(), qsTr("Chromatic is off. The fallback theme is applied."));
    }

    function runCtl(kind: string, command: var, doneText: string): void {
        if (ctlProc.running)
            return;
        ctlProc.kind = kind;
        ctlProc.doneText = doneText;
        ctlProc.command = command;
        notice = "";
        ctlProc.running = true;
    }

    // Wallpaper follow policy. `auto` runs the CLI follow verb (no
    // preview); `ask` previews the new palette and offers Apply / Keep.
    property bool followAsking: false

    function onWallpaperChanged(): void {
        if (Config.appearance.theme !== "hornero-chromatic")
            return;
        const policy = Config.appearance.chromatic.follow;
        if (policy === "auto") {
            runCtl("follow", Cli.followArgs(), "");
        } else if (policy === "ask") {
            followAsking = true;
            reset();
        }
    }

    function keepCurrent(): void {
        followAsking = false;
        cancel();
    }

    function applyAsked(): void {
        followAsking = false;
        apply(true);
    }

    Timer {
        id: debounce

        interval: 60
        onTriggered: root._start()
    }

    // A forgotten preview never outlives 30 s of inactivity.
    Timer {
        id: idleCancel

        interval: 30000
        onTriggered: Signal.cancelPreview()
    }

    // A helper that cannot even be started never reports an exit.
    Timer {
        id: probeTimeout

        interval: 2500
        onTriggered: {
            if (!root.helperChecked) {
                root.helperAvailable = false;
                root.helperChecked = true;
                root._fail(Cli.describeFailure(0, "", true, false));
            }
        }
    }

    Process {
        id: probeProc

        command: [root.helperPath, "version"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            probeTimeout.stop();
            root.helperAvailable = exitCode === 0;
            root.helperChecked = true;
            if (root.helperAvailable)
                root.regenerate();
            else
                root._fail(Cli.describeFailure(0, "", true, false));
        }
    }

    Process {
        id: generateProc

        property var args: []
        property bool video: false

        command: [root.helperPath].concat(args)
        stdout: StdioCollector {
            id: genOut
        }
        stderr: StdioCollector {
            id: genErr
        }
        onExited: exitCode => {
            if (root._again) {
                root._again = false;
                root._start();
                return;
            }
            if (exitCode !== 0) {
                root._fail(Cli.describeFailure(exitCode, genErr.text, false, generateProc.video));
                return;
            }
            const parsed = Cli.parseGenerate(genOut.text);
            if (!parsed.ok) {
                root._fail({
                    "code": "internal",
                    "title": qsTr("Chromatic failed"),
                    "detail": parsed.error
                });
                return;
            }
            root.errorCode = "";
            root.result = parsed.result;
            // Keep a live preview in step with the candidate.
            if (Signal.previewing) {
                Signal.beginPreview(parsed.result.scheme);
                idleCancel.restart();
            }
        }
    }

    Process {
        id: applyProc

        stdout: StdioCollector {
            id: applyOut
        }
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: exitCode => {
            root.applying = false;
            let doc = null;
            try {
                doc = JSON.parse(applyOut.text);
            } catch (e) {
                doc = null;
            }
            if (exitCode !== 0) {
                const code = doc?.error?.code ?? "chromatic.failed";
                const msg = doc?.error?.message ?? applyErr.text.trim();
                root.applyError = msg || code;
                Signal.cancelPreview();
                root.applyFailed(code, root.applyError);
                return;
            }
            const fp = String(doc?.fingerprint ?? "");
            if (fp && root.result && fp !== root.result.fingerprint)
                console.warn("ChromaticPreview: applied fingerprint differs from the previewed one; adopting the file");
            root.lastAppliedFingerprint = fp;
            Signal.commitPreview();
            root.followAsking = false;
            root.notice = qsTr("Applied.");
            root.applied(fp);
        }
    }

    Process {
        id: ctlProc

        property string kind: ""
        property string doneText: ""

        stdout: StdioCollector {
            id: ctlOut
        }
        stderr: StdioCollector {
            id: ctlErr
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.notice = ctlProc.doneText;
                if (ctlProc.kind === "import" || ctlProc.kind === "save")
                    root.savedPalettesChanged();
                Signal.reloadFromDisk();
            } else {
                let msg = ctlErr.text.trim();
                try {
                    msg = JSON.parse(ctlOut.text)?.error?.message ?? msg;
                } catch (e) {
                    // keep stderr
                }
                root.notice = qsTr("Could not %1: %2").arg(ctlProc.kind).arg(msg || qsTr("failed"));
            }
        }
    }

    Connections {
        target: Wallpapers

        function onActualCurrentChanged(): void {
            followDebounce.restart();
        }
    }

    Timer {
        id: followDebounce

        interval: 1500
        onTriggered: root.onWallpaperChanged()
    }
}
