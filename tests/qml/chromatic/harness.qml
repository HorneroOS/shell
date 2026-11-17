import QtQuick
import Quickshell
import qs.services
import qs.config
import "services/chromatic.js" as C

// Offscreen Signal/Chromatic probe. Driven by tests/chromatic_ui_harness.py:
// HSCENE selects the scenario; the result is one `HRESULT <json>` line.
ShellRoot {
    id: root

    readonly property string scene: Quickshell.env("HSCENE")
    property var out: ({})

    function emit(): void {
        console.log("HRESULT " + JSON.stringify(root.out));
        Qt.quit();
    }

    function candidate(): var {
        const t = JSON.parse(JSON.stringify(Signal.builtInThemes["hornero-signal-day"]));
        t.id = "hornero-chromatic";
        t.chromatic = {
            "version": 1,
            "resolved": {"mode": "light", "variant": "balanced"},
            "seeds": ["#D98A3A"],
            "fingerprint": "sha256:abc",
            "request": {"source": "wallpaper", "path": "/never/exposed.jpg"}
        };
        t.minSurfaceAlpha = {"base": 0.9, "panel": 0.92, "raised": 0.93};
        t.clearInk = {
            "light": {"ink": "#FAF5E6", "inkMuted": "#CFC7B4", "signal": "#FFAA33", "alert": "#FF7A66", "halo": "#0B0A08"},
            "dark": {"ink": "#14110C", "inkMuted": "#4A4338", "signal": "#8A4A00", "alert": "#A5301A", "halo": "#FFFDF7"}
        };
        return t;
    }

    function snapshotPalette(): var {
        return {"ground": String(Signal.current.ground), "signal": String(Signal.current.signal), "term4": String(Signal.current.term4), "id": Signal.themeId, "mode": Signal.themeMode};
    }

    // 400 palette consumers so a step's binding work is measured honestly.
    Repeater {
        model: 400

        Rectangle {
            required property int index

            width: 2
            height: 2
            color: index % 3 === 0 ? Signal.palette.panel : index % 3 === 1 ? Signal.tPalette.raised : Signal.palette.signal
            border.color: Signal.palette.rule
        }
    }

    // "service" scene: ChromaticPreview against the fake helper/horneroctl.
    property int finishedApplies: 0
    Connections {
        target: ChromaticPreview

        function onApplied(): void {
            root.finishedApplies++;
        }

        function onApplyFailed(): void {
            root.finishedApplies++;
        }
    }

    property int stage: 0
    property int stageTicks: 0
    Timer {
        id: svc

        interval: 100
        repeat: true
        onTriggered: {
            root.stageTicks++;
            const o = root.out;
            if (root.stageTicks > 150) {
                o.timeout = root.stage;
                svc.stop();
                root.emit();
                return;
            }
            const P = ChromaticPreview;
            if (root.stage === 0 && P.helperChecked) {
                o.helper = P.helperAvailable;
                if (!P.helperAvailable) {
                    o.errorCode = P.errorCode;
                    svc.stop();
                    root.emit();
                    return;
                }
                P.setSource("house", "");
                root.stage = 1;
            } else if (root.stage === 1 && !P.busy && (P.result || P.hasError)) {
                o.errorCode = P.errorCode;
                o.hasResult = !!P.result;
                if (P.result) {
                    o.fingerprint = P.result.fingerprint;
                    o.rows = P.result.gates.rows.length;
                    o.personality = P.result.inference.personality;
                    o.mode = P.result.scheme.mode;
                }
                const action = Quickshell.env("HACTION");
                if (action === "auto") {
                    // The policy: no Apply button. Three quick user changes
                    // collapse into one apply of the newest request.
                    P.set("contrast", "boosted");
                    P.set("contrast", "maximum");
                    P.set("hueShift", 10);
                    root.stage = 3;
                } else if (action === "preview" || action === "apply") {
                    o.themeBefore = Signal.themeId;
                    P.previewLive(true);
                    o.live = P.live;
                    o.themeDuring = Signal.themeId;
                    if (action === "preview") {
                        P.cancel();
                        o.liveAfterCancel = P.live;
                        o.themeAfter = Signal.themeId;
                        svc.stop();
                        root.emit();
                        return;
                    }
                    P.apply(true);
                    root.stage = 2;
                } else {
                    svc.stop();
                    root.emit();
                }
            } else if (root.stage === 3 && !P.busy && !P.applying && root.stageTicks > 12 && root.finishedApplies > 0) {
                o.applyError = P.applyError;
                o.undoKind = Undo.kind;
                o.undoKey = Undo.key;
                o.undoReason = Undo.reason;
                o.canUndo = Undo.canUndo;
                o.requestHue = P.request.hueShift;
                o.requestContrast = P.request.contrast;
                svc.stop();
                root.emit();
            } else if (root.stage === 2 && !P.applying) {
                o.applyError = P.applyError;
                o.notice = P.notice;
                o.liveAfterApply = P.live;
                o.themeAfterApply = Signal.themeId;
                svc.stop();
                root.emit();
            }
        }
    }

    Timer {
        id: undoWait

        property int phase: 0

        interval: 1600
        repeat: true
        onTriggered: {
            if (undoWait.phase === 0) {
                root.out.pausedStillActive = Undo.active;
                Undo.paused = false;
                undoWait.phase = 1;
            } else {
                root.out.expired = !Undo.active;
                undoWait.stop();
                root.emit();
            }
        }
    }

    property int settleTicks: 0
    Timer {
        id: settle

        interval: 250
        repeat: true
        onTriggered: {
            root.settleTicks++;
            if ((Experience.stateReady && Signal.themeStateReady) || root.settleTicks > 40) {
                settle.stop();
                root.emit();
            }
        }
    }
    Timer {
        id: waitTween

        interval: 10
        repeat: true
        onTriggered: {
            if (!Signal.transitionActive) {
                waitTween.stop();
                root.finishTween();
            }
        }
    }

    function finishTween(): void {
        root.out.steps = Signal.transitionSteps;
        root.out.finalGround = String(Signal.current.ground);
        root.out.targetGround = Signal.builtInThemes["hornero-signal-day"].palette.ground;
        root.emit();
    }

    Timer {
        interval: 800
        running: true
        onTriggered: {
            if (root.scene === "service") {
                ChromaticPreview.probe();
                svc.start();
                return;
            }
            if (root.scene === "idle") {
                // Warm-up run: wait until the first-run state files exist.
                settle.start();
                return;
            }
            Signal.applyBuiltInTheme("hornero-signal-night");
            Config.appearance.chromatic.transition = Quickshell.env("HTRANSITION") || "smooth";
            if (Quickshell.env("HREDUCED") === "1")
                Config.appearance.reducedMotion = true;
            if (Quickshell.env("HHC") === "1")
                Config.appearance.highContrast = true;
            const o = root.out;
            o.allowed = Signal.transitionAllowed;
            o.before = root.snapshotPalette();
            if (root.scene === "preview") {
                o.refused = Signal.beginPreview({"palette": {"ink": "#FFFFFF"}});
                o.refusedPreviewing = Signal.previewing;
                o.begun = Signal.beginPreview(root.candidate());
                o.previewing = Signal.previewing;
                // The preview is instant here (transition=instant) so the
                // palette is observable immediately.
                o.during = root.snapshotPalette();
                o.chromatic = Signal.chromatic;
                o.clearInk = Signal.clearInk !== null;
                o.minSurfaceAlpha = Signal.minSurfaceAlpha;
                // A live file arriving mid-preview becomes the restore
                // point, not the screen.
                Signal.load(JSON.stringify({"schemaVersion": 2, "id": "hornero-signal-day", "mode": "light", "palette": Signal.builtInThemes["hornero-signal-day"].palette, "terminal": Signal.builtInThemes["hornero-signal-day"].terminal}));
                o.duringFile = root.snapshotPalette();
                Signal.cancelPreview();
                o.afterCancel = root.snapshotPalette();
                o.previewingAfter = Signal.previewing;
                o.chromaticAfter = Signal.chromatic;
                o.clearInkAfter = Signal.clearInk;
                o.minSurfaceAlphaAfter = Signal.minSurfaceAlpha;
                root.emit();
            } else if (root.scene === "commit") {
                Signal.beginPreview(root.candidate());
                Signal.commitPreview();
                o.previewing = Signal.previewing;
                Signal.cancelPreview();
                o.afterCancelNoop = root.snapshotPalette();
                root.emit();
            } else if (root.scene === "tween") {
                Signal.beginPreview(root.candidate());
                o.active = Signal.transitionActive;
                if (o.active) {
                    waitTween.start();
                } else {
                    o.steps = Signal.transitionSteps;
                    root.emit();
                }
            } else if (root.scene === "hc") {
                Signal.beginPreview(root.candidate());
                o.palette = String(Signal.palette.ground);
                o.current = String(Signal.current.ground);
                o.contrast = String(Signal.contrastPalette.ground);
                o.inkSets = ClearInk.sets;
                o.style = ClearInk.style;
                root.emit();
            } else if (root.scene === "clear") {
                Signal.beginPreview(root.candidate());
                o.sets = ClearInk.sets;
                o.style = ClearInk.style;
                root.emit();
            } else if (root.scene === "alpha") {
                Config.appearance.transparency.enabled = true;
                Config.appearance.transparency.base = 0.5;
                Config.appearance.transparency.layers = 0.4;
                o.plain = {"panel": Signal.elementAlpha("launcher"), "bar": Signal.elementAlpha("bar"), "layer0": Signal.layer("#102030", 0).a, "layer1": Signal.layer("#102030", 1, "panel").a};
                Signal.beginPreview(root.candidate());
                o.floored = {"panel": Signal.elementAlpha("launcher"), "bar": Signal.elementAlpha("bar"), "layer0": Signal.layer("#102030", 0).a, "layer1": Signal.layer("#102030", 1, "panel").a, "surface": Signal.surface("#102030", "launcher").a};
                Config.appearance.transparency.elements = {"launcher": 0.99, "bar": 0.0};
                o.explicit = {"launcher": Signal.elementAlpha("launcher")};
                root.emit();
            } else if (root.scene === "undo") {
                const calls = [];
                o.defaultSeconds = Config.controlCenter.undoSeconds;
                Undo.offer("a", "A", () => {
                    calls.push("a1");
                    return true;
                }, "detail");
                o.offered = [Undo.kind, Undo.key, Undo.canUndo];
                // Same key: the FIRST restore point is kept.
                Undo.offer("a", "A2", () => {
                    calls.push("a2");
                    return true;
                }, "");
                o.coalescedTitle = Undo.title;
                Undo.undo();
                o.callsAfterFirst = calls.slice();
                o.afterUndo = [Undo.kind, Undo.canUndo];
                // A different key replaces the offer on screen.
                Undo.offer("b", "B", () => {
                    calls.push("b");
                    return true;
                }, "");
                Undo.offer("c", "C", () => {
                    calls.push("c");
                    return true;
                }, "");
                Undo.undo();
                o.callsAfterReplace = calls.slice();
                // A restore that fails says why and changes nothing else.
                Undo.offer("d", "D", () => false, "");
                Undo.undo();
                o.failFalse = [Undo.kind, Undo.reason.length > 0, Undo.canUndo];
                Undo.offer("e", "E", () => "disk full", "");
                Undo.undo();
                o.failString = [Undo.kind, Undo.reason];
                Undo.offer("f", "F", () => {
                    throw new Error("boom");
                }, "");
                Undo.undo();
                o.failThrow = [Undo.kind, Undo.reason.indexOf("boom") >= 0];
                Undo.report("g", "G", "because");
                o.report = [Undo.kind, Undo.reason, Undo.canUndo];
                Undo.dismiss();
                o.dismissed = Undo.active;
                // Plain config values restore exactly.
                const restore = Undo.restorer([
                    {
                        "obj": Config.controlCenter,
                        "keys": ["undoSeconds"]
                    }
                ]);
                Config.controlCenter.undoSeconds = 42;
                restore();
                o.restorer = Config.controlCenter.undoSeconds;
                // Timing: paused strips wait, free ones expire.
                Config.controlCenter.undoSeconds = 1;
                Undo.offer("h", "H", () => true, "");
                Undo.paused = true;
                undoWait.start();
            } else if (root.scene === "cost") {
                const from = Signal._currentFlat();
                const to = C.flatten(root.candidate());
                const n = 120;
                const t0 = Date.now();
                for (let i = 0; i < n; i++)
                    Signal._assign(C.frame(from, to, i % 12 + 1, 12));
                o.stepMs = (Date.now() - t0) / n;
                o.maxSteps = C.MAX_STEPS;
                root.emit();
            } else {
                root.emit();
            }
        }
    }
}
