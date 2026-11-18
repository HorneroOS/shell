pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.utils
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
    // Where the helper may live, in order: HORNERO_CHROMATIC_BIN, the packaged
    // /usr/lib/hornero/hornero-chromatic, then the person's own build in
    // ~/.local/lib/hornero or ~/.local/bin (development or per-user install).
    // The probe tries each in turn and settles on the first that answers
    // `version`; only when none does is the engine reported as not installed.
    readonly property var helperCandidates: {
        const home = Quickshell.env("HOME") || "";
        const list = [Quickshell.env("HORNERO_CHROMATIC_BIN"), "/usr/lib/hornero/hornero-chromatic"];
        if (home)
            list.push(home + "/.local/lib/hornero/hornero-chromatic", home + "/.local/bin/hornero-chromatic");
        return list.filter(p => !!p);
    }
    property int helperIndex: 0
    readonly property string helperPath: helperCandidates[Math.min(helperIndex, helperCandidates.length - 1)]
    readonly property string wallpaper: Wallpapers.actualCurrent
    readonly property var perMode: ({
            "dark": {
                "variant": Config.appearance.chromatic.perMode.dark.variant
            },
            "light": {
                "variant": Config.appearance.chromatic.perMode.light.variant
            }
        })

    // In-process engine (Hornero.Chromatic) when the module is installed;
    // the helper process is the fallback. `engineName` says which is live.
    property var _engine: null
    readonly property string engineName: _engine ? "in-process" : (helperAvailable ? "helper" : "none")

    function _loadEngine(): void {
        const comp = Qt.createComponent(Qt.resolvedUrl("ChromaticInProcess.qml"));
        if (comp.status !== Component.Ready) {
            comp.destroy();
            return;
        }
        const obj = comp.createObject(root);
        if (!obj || !obj.available)
            return;
        obj.finished.connect(result => root._onEngineResult(result));
        obj.failed.connect((code, message) => root._onEngineFailed(code, message));
        root._engine = obj;
    }

    function _onEngineResult(doc: var): void {
        const parsed = Cli.parseDocument(doc);
        if (!parsed.ok) {
            _fail({
                "code": "internal",
                "title": qsTr("Chromatic failed"),
                "detail": parsed.error
            });
            return;
        }
        _adopt(parsed.result);
    }

    function _onEngineFailed(code: string, message: string): void {
        const video = request.source !== "seed" && request.source !== "house" && Cli.isVideoPath(request.source === "image" ? request.path : wallpaper);
        _fail(Cli.describeFailure(Cli.engineFailureExit(code), message, false, video));
    }

    // Shared by the helper and in-process paths.
    function _adopt(result: var): void {
        errorCode = "";
        root.result = result;
        if (root.followAsking && !Signal.previewing) {
            Signal.beginPreview(result.scheme);
            askTimer.restart();
            Toaster.toast(qsTr("Wallpaper changed"), qsTr("Previewing the matching Chromatic palette. Open Appearance, Chromatic to apply it; it reverts in 10 seconds."), "palette");
            return;
        }
        if (Signal.previewing) {
            Signal.beginPreview(result.scheme);
            idleCancel.restart();
        }
    }

    // ---- per-variant palettes ------------------------------------------
    // The Variant gallery shows each variant's real palette for the current
    // source and settings (RFC 0002 §6). They come from the same engine as
    // `result`, one variant at a time, only while a gallery asks for them
    // (`variantPreviewsWanted`), and live in memory only.
    //
    // variantSchemes[id] is that variant's scheme ({palette, terminal}),
    // variantFailed[id] is true when the engine refused it (for example
    // Neon in light mode); an id in neither is still pending.
    property bool variantPreviewsWanted: false
    property var variantSchemes: ({})
    property var variantFailed: ({})
    property string _variantSig: ""
    property var _variantQueue: []
    property string _variantCurrent: ""
    property bool _variantDiscard: false
    property var _variantEngine: null

    function _variantSignature(): string {
        const r = JSON.parse(JSON.stringify(request));
        delete r.variant;
        return JSON.stringify([r, wallpaper, perMode, !!_engine]);
    }

    // Recompute when the source or any non-variant setting changed.
    function refreshVariantPreviews(): void {
        if (!variantPreviewsWanted)
            return;
        // No engine and no helper (yet): tiles stay empty wells, they do
        // not claim a variant failed.
        if (!_engine && !helperAvailable) {
            probe();
            return;
        }
        const sig = _variantSignature();
        if (sig === _variantSig)
            return;
        _variantSig = sig;
        // A run still in flight belongs to the old settings: drop its result.
        _variantDiscard = _variantCurrent !== "";
        variantSchemes = {};
        variantFailed = {};
        _variantQueue = Cli.VARIANTS.map(v => v.id);
        _variantNext();
    }

    function _variantRequest(id: string): var {
        const r = JSON.parse(JSON.stringify(request));
        r.variant = id;
        return r;
    }

    function _variantNext(): void {
        if (_variantCurrent !== "")
            return;
        while (_variantQueue.length > 0) {
            const id = _variantQueue[0];
            _variantQueue = _variantQueue.slice(1);
            if (_variantStart(id))
                return;
            _variantSet(id, null);
        }
    }

    function _variantStart(id: string): bool {
        const req = _variantRequest(id);
        if (_engine) {
            const ereq = Cli.engineRequest(req, wallpaper, perMode);
            if (!ereq)
                return false;
            if (!_variantEngine) {
                const comp = Qt.createComponent(Qt.resolvedUrl("ChromaticInProcess.qml"));
                const obj = comp.status === Component.Ready ? comp.createObject(root) : null;
                if (!obj || !obj.available)
                    return false;
                obj.finished.connect(doc => root._variantDone(Cli.parseDocument(doc)));
                obj.failed.connect(() => root._variantDone({
                        "ok": false
                    }));
                _variantEngine = obj;
            }
            _variantCurrent = id;
            _variantEngine.generate(ereq);
            return true;
        }
        if (!helperAvailable)
            return false;
        const args = Cli.helperArgs(req, wallpaper, perMode);
        if (!args)
            return false;
        _variantCurrent = id;
        variantProc.args = args;
        variantProc.running = true;
        return true;
    }

    function _variantSet(id: string, scheme: var): void {
        const ok = Object.assign({}, variantSchemes);
        const bad = Object.assign({}, variantFailed);
        if (scheme)
            ok[id] = scheme;
        else
            bad[id] = true;
        variantSchemes = ok;
        variantFailed = bad;
    }

    function _variantDone(parsed: var): void {
        const id = _variantCurrent;
        _variantCurrent = "";
        const stale = _variantDiscard;
        _variantDiscard = false;
        if (id !== "" && !stale)
            _variantSet(id, parsed && parsed.ok ? parsed.result.scheme : null);
        _variantNext();
    }

    // ---- hover preview of a variant -------------------------------------
    // Transient: shows a variant's palette on the live shell while the
    // pointer or keyboard focus rests on its tile, and puts back whatever
    // was shown before (the candidate the user is already previewing, or
    // the applied theme) when it leaves. Memory only, self-cancelling after
    // 30 s, and instant under reduced motion (Signal.transitionAllowed).
    property string hoveredVariant: ""
    property bool _resumeLive: false

    function hoverVariant(id: string): void {
        const scheme = id === "" ? null : variantSchemes[id] ?? null;
        if (!scheme)
            return;
        if (hoveredVariant === "")
            _resumeLive = Signal.previewing;
        if (Signal.beginPreview(scheme)) {
            hoveredVariant = id;
            idleCancel.restart();
        }
    }

    // `id` is the tile that was left ("" ends any hover); a tile entered a moment earlier keeps
    // its preview (Qt may deliver the old tile's exit after the new tile's
    // enter).
    function endHover(id: string): void {
        if (hoveredVariant === "" || (id && id !== hoveredVariant))
            return;
        hoveredVariant = "";
        // Back to the candidate the user was already previewing, else to the real theme.
        if (_resumeLive && result)
            Signal.beginPreview(result.scheme);
        else
            Signal.cancelPreview();
    }

    onVariantPreviewsWantedChanged: {
        if (variantPreviewsWanted)
            _variantTrigger.restart();
    }
    onHelperAvailableChanged: _variantTrigger.restart()
    onRequestChanged: _variantTrigger.restart()
    onWallpaperChanged: _variantTrigger.restart()

    Timer {
        id: _variantTrigger

        // Behind the main preview, which always goes first.
        interval: 250
        onTriggered: {
            if (root.busy)
                restart();
            else
                root.refreshVariantPreviews();
        }
    }

    Process {
        id: variantProc

        property var args: []

        command: [root.helperPath].concat(args)
        stdout: StdioCollector {
            id: variantOut
        }
        onExited: exitCode => root._variantDone(exitCode === 0 ? Cli.parseGenerate(variantOut.text) : {
                "ok": false
            })
    }

    Component.onCompleted: _loadEngine()

    property bool _again: false
    property string _idleToken: ""

    signal savedPalettesChanged
    signal applied(string fingerprint)
    signal applyFailed(string code, string message)

    function probe(): void {
        if (_engine) {
            helperAvailable = true;
            helperChecked = true;
            return;
        }
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
        if (_engine) {
            const ereq = Cli.engineRequest(request, wallpaper, perMode);
            if (!ereq) {
                result = null;
                errorCode = "no-source";
                errorTitle = request.source === "image" ? qsTr("Choose an image") : request.source === "seed" ? qsTr("Choose an accent colour") : qsTr("No wallpaper is set");
                errorDetail = qsTr("Chromatic needs a source to build a palette from.");
                return;
            }
            _engine.generate(ereq);
            return;
        }
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
        askTimer.stop();
        followAsking = false;
        cancel();
    }

    function applyAsked(): void {
        askTimer.stop();
        followAsking = false;
        apply(true);
    }

    Timer {
        id: debounce

        interval: 60
        onTriggered: root._start()
    }

    // `ask` policy: Keep current on timeout.
    Timer {
        id: askTimer

        interval: 10000
        onTriggered: root.keepCurrent()
    }

    // A forgotten preview never outlives 30 s of inactivity.
    Timer {
        id: idleCancel

        interval: 30000
        onTriggered: {
            root.hoveredVariant = "";
            Signal.cancelPreview();
        }
    }

    // A helper that cannot even be started never reports an exit.
    Timer {
        id: probeTimeout

        interval: 1500
        onTriggered: {
            if (!root.helperChecked && root.helperIndex + 1 < root.helperCandidates.length) {
                // A path that cannot start never reports an exit: move on.
                root.helperIndex += 1;
                probeProc.running = false;
                probeProc.running = true;
                restart();
                return;
            }
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
            if (exitCode !== 0 && root.helperIndex + 1 < root.helperCandidates.length) {
                // Not here: try the next known location.
                root.helperIndex += 1;
                probeTimeout.restart();
                probeProc.running = true;
                return;
            }
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
            root._adopt(parsed.result);
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
