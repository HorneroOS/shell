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
//
// Policy (docs/CONTROL-CENTER-APPLY.md): there is no Apply button. A user
// change (`set`, `setSource`, `enable`) regenerates the candidate, and the
// newest finished candidate is applied once the controls have been quiet
// for `applyQuietMs`. One apply runs at a time; changes made meanwhile
// collapse into one more apply of the newest request (newest wins). Every
// apply offers "Applied · Undo" (services/Undo.qml) and a failure is
// reported with its reason and leaves the previous palette in place.
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
    // A change asked for an apply that has not started yet / must run again.
    property bool _applyWanted: false
    property bool _applyAgain: false
    // The apply in flight is an Undo restore (never offers Undo itself).
    property bool _undoing: false
    // Quiet time after the last change before the newest candidate applies.
    readonly property int applyQuietMs: 350
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
        if (Signal.previewing) {
            Signal.beginPreview(result.scheme);
            idleCancel.restart();
        }
        // A user change is waiting for its candidate: apply it when quiet.
        if (root._applyWanted)
            applyQuiet.restart();
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
        _change(Cli.normalise(r, Signal.themeMode));
    }

    function set(key: string, value: var): void {
        const r = JSON.parse(JSON.stringify(request));
        r[key] = value;
        _change(Cli.normalise(r, Signal.themeMode));
    }

    // A user change: choosing what is already applied does nothing, anything
    // else rebuilds the candidate and applies it once the controls are quiet.
    function _change(next: var): void {
        if (JSON.stringify(next) === JSON.stringify(request) && Config.appearance.theme === "hornero-chromatic")
            return;
        request = next;
        _applyWanted = true;
        regenerate();
    }

    // Turn Chromatic on with the current request (the "Use Chromatic" switch).
    function enable(): void {
        if (!result) {
            _applyWanted = true;
            regenerate();
            return;
        }
        _applyWanted = true;
        applyQuiet.restart();
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
                _applyWanted = false;
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
            _applyWanted = false;
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
        _applyWanted = false;
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

    // What Undo puts back: whether Chromatic was on, the theme that was
    // live, and the saved Chromatic preferences.
    function _snapshot(): var {
        return {
            "active": Config.appearance.theme === "hornero-chromatic",
            "themeId": Signal.themeId,
            "prefs": root._prefsCopy(),
            "request": Cli.normalise(Config.appearance.chromatic, Signal.themeMode)
        };
    }

    // Plain copy of the saved preferences (a JsonObject does not stringify).
    function _prefsCopy(): var {
        const c = Config.appearance.chromatic;
        return {
            "source": c.source,
            "seeds": Array.from(c.seeds ?? []),
            "variant": c.variant,
            "mode": c.mode,
            "contrast": c.contrast,
            "surfaceDepth": c.surfaceDepth,
            "chroma": c.chroma,
            "hueShift": c.hueShift,
            "follow": c.follow,
            "transition": c.transition
        };
    }

    function _restoreSnapshot(snap: var): var {
        if (applying)
            return qsTr("Another palette change is still running. Try again in a moment.");
        if (snap.active) {
            _undoing = true;
            _runApply(snap.request, true);
            return true;
        }
        // Chromatic was off: bring the old theme back, then the old preferences.
        ThemePipeline.applyTheme(snap.themeId, "");
        const p = snap.prefs;
        const c = Config.appearance.chromatic;
        for (const k of ["source", "variant", "mode", "contrast", "surfaceDepth", "chroma", "hueShift", "follow", "transition"]) {
            if (p[k] !== undefined)
                c[k] = p[k];
        }
        c.seeds = p.seeds ?? [];
        Config.save();
        reset();
        return true;
    }

    // Persist through horneroctl. `persist` false = one-off (no preferences).
    // One apply at a time: a second call while one runs applies the newest
    // request once more when the first finishes.
    function apply(persist: bool): void {
        if (!result && !_undoing)
            return;
        if (applying) {
            _applyAgain = true;
            return;
        }
        _runApply(request, persist !== false);
    }

    function _runApply(req: var, persist: bool): void {
        _applyWanted = false;
        applyError = "";
        applying = true;
        applyProc.snap = _undoing ? null : _snapshot();
        applyProc.command = Cli.applyArgs(req, perMode, persist);
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
        runCtl("off", Cli.offArgs(), qsTr("Chromatic is off. The fallback theme is applied."), _snapshot());
    }

    // `undoWith`: a snapshot to restore, or null for verbs that undo
    // through the palette history (`follow`) or have no undo (`save`).
    function runCtl(kind: string, command: var, doneText: string, undoWith: var): void {
        if (ctlProc.running)
            return;
        ctlProc.kind = kind;
        ctlProc.doneText = doneText;
        ctlProc.snap = undoWith ?? null;
        ctlProc.command = command;
        notice = "";
        ctlProc.running = true;
    }

    // Wallpaper follow policy. `auto` (and the retired `ask`, which now
    // behaves as `auto`) re-derives the palette and offers Undo, which is
    // the palette history's one-step rollback.
    function onWallpaperChanged(): void {
        if (Config.appearance.theme !== "hornero-chromatic")
            return;
        const policy = Config.appearance.chromatic.follow;
        if (policy === "auto" || policy === "ask")
            runCtl("follow", Cli.followArgs(), "");
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
        onTriggered: {
            root.hoveredVariant = "";
            Signal.cancelPreview();
        }
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
            root._adopt(parsed.result);
        }
    }

    Process {
        id: applyProc

        property var snap: null

        stdout: StdioCollector {
            id: applyOut
        }
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: exitCode => {
            root.applying = false;
            const undoing = root._undoing;
            root._undoing = false;
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
                root._applyAgain = false;
                root.applyFailed(code, root.applyError);
                Undo.report("chromatic", undoing ? qsTr("Could not undo the Chromatic palette") : qsTr("Chromatic was not applied"), qsTr("%1 Your previous palette is still in place.").arg(root.applyError));
                return;
            }
            const fp = String(doc?.fingerprint ?? "");
            if (fp && root.result && fp !== root.result.fingerprint)
                console.warn("ChromaticPreview: applied fingerprint differs from the previewed one; adopting the file");
            root.lastAppliedFingerprint = fp;
            Signal.commitPreview();
            root.notice = "";
            root.applied(fp);
            if (!undoing && applyProc.snap) {
                const snap = applyProc.snap;
                Undo.offer("chromatic", qsTr("Chromatic palette"), () => root._restoreSnapshot(snap), root.result ? qsTr("%1, %2").arg(root.result.inference?.variant ?? request.variant).arg(root.result.scheme.mode ?? "") : "");
            }
            if (root._applyAgain) {
                root._applyAgain = false;
                root.apply(true);
            }
        }
    }

    Timer {
        id: applyQuiet

        interval: root.applyQuietMs
        onTriggered: {
            // Still building the newest candidate: wait for it.
            if (root.busy || !root.result) {
                if (root._applyWanted)
                    restart();
                return;
            }
            root._applyWanted = false;
            root.apply(true);
        }
    }

    Process {
        id: ctlProc

        property string kind: ""
        property string doneText: ""
        property var snap: null

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
                // A follow right after the person changed the wallpaper rides on that
                // change's Undo (restoring the wallpaper re-derives the palette); it
                // never replaces it, and never offers an undo of an undo.
                const folded = Undo.kind === "undone" || (Undo.kind === "applied" && Undo.key === "appearance");
                if (ctlProc.kind === "follow") {
                    if (!folded)
                        Undo.offer("chromatic", qsTr("Palette follows the wallpaper"), () => root.rollback() || true, qsTr("Undo returns to the previous palette."));
                } else if (ctlProc.kind === "off" && ctlProc.snap) {
                    const snap = ctlProc.snap;
                    Undo.offer("chromatic", qsTr("Chromatic turned off"), () => root._restoreSnapshot(snap), "");
                }
            } else {
                let msg = ctlErr.text.trim();
                try {
                    msg = JSON.parse(ctlOut.text)?.error?.message ?? msg;
                } catch (e) {
                    // keep stderr
                }
                root.notice = qsTr("Could not %1: %2").arg(ctlProc.kind).arg(msg || qsTr("failed"));
                if (ctlProc.kind === "follow" || ctlProc.kind === "off")
                    Undo.report("chromatic", qsTr("Chromatic did not change"), root.notice);
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
