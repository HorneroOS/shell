pragma Singleton

import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

// The Control Center's one apply policy (docs/CONTROL-CENTER-APPLY.md):
// every setting takes effect the moment it is chosen. There is no Apply
// button. Changes that are risky, slow or hard to put back by hand (layout
// and bar presets, themes and Chromatic palettes, keyboard layouts,
// display modes, bulk resets...) also make an offer after they applied,
// and the Control Center shows a non-blocking "Applied · Undo" strip for
// `Config.controlCenter.undoSeconds`.
//
// Contract
//   * One offer at a time. A new change under another key replaces the
//     offer on screen (the older change simply stays applied).
//   * Changes under the same key coalesce: the FIRST restore is kept, so
//     dragging through five accents undoes all five at once.
//   * Restores never live in a pane. Panes unload when you navigate away
//     and the window is destroyed when it closes, so a closure created in a
//     pane would fail later. Callers describe the restore as data and the
//     work runs here or in another singleton:
//       offerCommand  - run an argv (Undo owns the process)
//       offerValues   - write remembered values back into Config objects
//       offerPaths    - write remembered values back by Config path
//       offerCalls    - call methods on singletons (ThemePipeline, Experience...)
//       offer         - a closure; ONLY from singletons (their context lives on)
//   * A restore returns true (done), false or a reason string (failed: the
//     strip says why and nothing else changes), or `Undo.busy` when what it
//     needs is still working: the undo then waits and retries for up to
//     10 s with the offer kept, instead of failing or claiming success.
//   * The countdown pauses while the strip is hovered or focused. Holds are
//     counted, and a destroyed strip lets go of all of them (`releaseAll`).
//   * Closing the Control Center dismisses the offer; it never outlives the
//     window that showed it.
//   * `report()` is the failure side: the apply failed and was reverted, the
//     strip says what and why.
Singleton {
    id: root

    // "" (nothing), "applied" (offer with Undo), "undoing", "undone", "failed".
    property string kind: ""
    property string key: ""
    property string title: ""
    property string detail: ""
    property string reason: ""
    // Hover/focus holds on the strip; the countdown waits while > 0.
    property int holds: 0
    readonly property bool paused: holds > 0
    readonly property bool active: kind !== ""
    readonly property bool canUndo: kind === "applied" && _restore !== null
    readonly property int totalMs: Math.max(1000, Math.round(Config.controlCenter.undoSeconds * 1000))
    property int remainingMs: 0
    property int holdMs: 0
    // Offers made over the lifetime of the shell, for tests and diagnostics.
    property int offered: 0
    // Returned by a restore whose subsystem is still busy (see contract).
    readonly property var busy: ({
            "busy": true
        })

    signal undone(string key)
    signal failed(string key, string reason)
    // A restore command finished (offerCommand); panes that are alive refresh.
    signal commandFinished(string key, bool ok)

    property var _restore: null
    property var _retry: null
    property int _retryMs: 0

    // ---- offers -----------------------------------------------------------

    // Record that `title` was just applied and how to put it back.
    // `restore` is `() => bool | string | Undo.busy`. From singletons only.
    function offer(key: string, title: string, restore: var, detail: string): void {
        if (typeof restore !== "function")
            return;
        if (root.kind === "applied" && root.key === key && root._restore !== null) {
            // Same change continuing: keep the first restore point.
            root.title = title;
            root.detail = detail ?? "";
        } else {
            root._stopRetry();
            root.kind = "applied";
            root.key = key;
            root.title = title;
            root.detail = detail ?? "";
            root.reason = "";
            root._restore = restore;
            root.offered++;
        }
        root._arm(root.totalMs);
    }

    // Undo runs `argv` itself (no shell string unless a caller passes one on
    // purpose). Busy while an earlier restore command still runs.
    function offerCommand(key: string, title: string, argv: var, detail: string): void {
        const cmd = Array.from(argv);
        root.offer(key, title, () => root._runCommand(key, title, cmd), detail);
    }

    // Remember `keys` of each Config object now; Undo writes them back.
    //   Undo.offerValues("k", "T", [{obj: Config.bar.sizes, keys: ["innerWidth"]}], "")
    function offerValues(key: string, title: string, targets: var, detail: string): void {
        root.offer(key, title, root.restorer(targets), detail);
    }

    // `entries` = [{path: "appearance.theme", value: …}] (values as they were).
    function offerPaths(key: string, title: string, entries: var, detail: string): void {
        const saved = entries.map(e => ({
                    "path": e.path,
                    "value": root._copy(e.value)
                }));
        root.offer(key, title, () => {
            for (const e of saved)
                root.setPath(e.path, root._copy(e.value));
            Config.save();
            return true;
        }, detail);
    }

    // `calls` = [[singletonObject, "method", [args…]], …]; a call that returns
    // `Undo.busy`, false, or a string starting with "error" stops there.
    function offerCalls(key: string, title: string, calls: var, detail: string): void {
        const saved = calls.map(c => [c[0], c[1], Array.from(c[2] ?? [])]);
        root.offer(key, title, () => {
            for (const c of saved) {
                const r = c[0][c[1]](...c[2]);
                if (r === root.busy || r === false)
                    return r;
                if (typeof r === "string" && r.startsWith("error"))
                    return r;
            }
            return true;
        }, detail);
    }

    // A restore callback for plain config values: remembers `keys` of each
    // `obj` as they are right now and writes them back (then saves once).
    // The closure is created here, so it survives the caller.
    function restorer(targets: var): var {
        const saved = targets.map(t => ({
                    "obj": t.obj,
                    "values": t.keys.map(k => [k, root._copy(t.obj[k])])
                }));
        return () => {
            for (const entry of saved) {
                for (const kv of entry.values)
                    entry.obj[kv[0]] = root._copy(kv[1]);
            }
            Config.save();
            return true;
        };
    }

    function setPath(path: string, value: var): void {
        const parts = path.split(".");
        let obj = Config;
        for (let i = 0; i < parts.length - 1; i++)
            obj = obj[parts[i]];
        obj[parts[parts.length - 1]] = value;
    }

    function valueAt(path: string): var {
        let obj = Config;
        for (const p of path.split("."))
            obj = obj[p];
        return obj;
    }

    // The apply failed and was reverted by the caller; say why.
    function report(key: string, title: string, why: string): void {
        root._stopRetry();
        root.kind = "failed";
        root.key = key;
        root.title = title;
        root.detail = "";
        root.reason = why && why.length > 0 ? why : qsTr("The change was not applied.");
        root._restore = null;
        root._arm(Math.max(root.totalMs, 8000));
        root.failed(key, root.reason);
    }

    // ---- undo ---------------------------------------------------------------

    function undo(): void {
        if (!root.canUndo)
            return;
        root._attempt(root._restore);
    }

    function _attempt(restore: var): void {
        const key = root.key;
        const title = root.title;
        let result = true;
        try {
            result = restore();
        } catch (e) {
            result = String(e);
        }
        if (result === root.busy) {
            // Keep the restore and try again shortly; the offer stays.
            root.kind = "undoing";
            root._retry = restore;
            if (root._retryMs <= 0)
                root._retryMs = 10000;
            tick.stop();
            retry.restart();
            return;
        }
        root._stopRetry();
        root._restore = null;
        if (result === false || typeof result === "string") {
            root.report(key, qsTr("Could not undo %1").arg(title), typeof result === "string" ? result : "");
            return;
        }
        root.kind = "undone";
        root.key = key;
        root.reason = "";
        root._arm(3000);
        root.undone(key);
    }

    function dismiss(): void {
        root._stopRetry();
        root.kind = "";
        root.key = "";
        root.title = "";
        root.detail = "";
        root.reason = "";
        root._restore = null;
        root.remainingMs = 0;
        tick.stop();
    }

    // Drop an offer that is no longer true (for example the file it would
    // restore changed underneath it). Only the matching key is touched.
    function withdraw(key: string): void {
        if (root.key === key && root.kind === "applied")
            root.dismiss();
    }

    function hold(): void {
        root.holds++;
    }

    function release(): void {
        root.holds = Math.max(0, root.holds - 1);
    }

    // The strip that held is gone (window closed): nothing may stay paused.
    function releaseAll(): void {
        root.holds = 0;
    }

    function _copy(v: var): var {
        if (v === undefined)
            return null;
        if (Array.isArray(v))
            return JSON.parse(JSON.stringify(Array.from(v)));
        if (v !== null && typeof v === "object")
            return JSON.parse(JSON.stringify(v));
        return v;
    }

    function _stopRetry(): void {
        retry.stop();
        root._retry = null;
        root._retryMs = 0;
    }

    function _arm(ms: int): void {
        root.holdMs = ms;
        root.remainingMs = ms;
        tick.restart();
    }

    // ---- restore commands ----------------------------------------------------

    property string _cmdKey: ""
    property string _cmdTitle: ""

    function _runCommand(key: string, title: string, cmd: var): var {
        if (cmdProc.running)
            return root.busy;
        root._cmdKey = key;
        root._cmdTitle = title;
        cmdProc.command = cmd;
        cmdProc.running = true;
        return true;
    }

    Process {
        id: cmdProc

        stdout: StdioCollector {
            id: cmdOut
        }
        stderr: StdioCollector {
            id: cmdErr
        }
        onExited: exitCode => {
            let ok = exitCode === 0;
            let why = cmdErr.text.trim().split("\n").slice(-1)[0];
            try {
                const doc = JSON.parse(cmdOut.text.trim());
                if (doc && doc.ok === false) {
                    ok = false;
                    why = String(doc.message ?? doc.error?.message ?? why);
                }
            } catch (e) {
                // not JSON: the exit code decides
            }
            if (!ok)
                root.report(root._cmdKey, qsTr("Could not undo %1").arg(root._cmdTitle), why || qsTr("The command failed."));
            root.commandFinished(root._cmdKey, ok);
        }
    }

    Timer {
        id: tick

        interval: 100
        repeat: true
        onTriggered: {
            if (root.paused)
                return;
            root.remainingMs = Math.max(0, root.remainingMs - interval);
            if (root.remainingMs <= 0)
                root.dismiss();
        }
    }

    Timer {
        id: retry

        interval: 250
        onTriggered: {
            if (!root._retry)
                return;
            root._retryMs -= interval;
            if (root._retryMs <= 0) {
                const title = root.title;
                const key = root.key;
                root._stopRetry();
                root._restore = null;
                root.report(key, qsTr("Could not undo %1").arg(title), qsTr("It was still busy after 10 seconds. Change the setting back by hand."));
                return;
            }
            root._attempt(root._retry);
        }
    }
}
