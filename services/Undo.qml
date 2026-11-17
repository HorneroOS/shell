pragma Singleton

import qs.config
import qs.services
import Quickshell
import QtQuick

// The Control Center's one apply policy (docs/CONTROL-CENTER-APPLY.md):
// every setting takes effect the moment it is chosen. There is no Apply
// button. Changes that are risky, slow or hard to put back by hand (layout
// and bar presets, themes and Chromatic palettes, keyboard layouts,
// display modes, bulk resets...) also call `offer()` after they applied,
// and the Control Center shows a non-blocking "Applied · Undo" strip for
// `Config.controlCenter.undoSeconds`.
//
// Contract
//   * One offer at a time. A new change under another key replaces the
//     offer on screen (the older change simply stays applied).
//   * Changes under the same key coalesce: the FIRST restore callback is
//     kept, so dragging through five accents undoes all five at once.
//   * `restore` puts the previous value back by the same atomic path that
//     applied it. It may return false or a string (the reason) to say it
//     failed, or throw; the strip then says why and nothing else changes.
//   * The countdown pauses while the strip is hovered or focused.
//   * `report()` is the failure side: the apply failed and was reverted, the
//     strip says what and why.
Singleton {
    id: root

    // "" (nothing), "applied" (offer with Undo), "undone", "failed".
    property string kind: ""
    property string key: ""
    property string title: ""
    property string detail: ""
    property string reason: ""
    // The strip is hovered or has keyboard focus: the countdown waits.
    property bool paused: false
    readonly property bool active: kind !== ""
    readonly property bool canUndo: kind === "applied" && _restore !== null
    readonly property int totalMs: Math.max(1000, Math.round(Config.controlCenter.undoSeconds * 1000))
    property int remainingMs: 0
    // Offers made over the lifetime of the shell, for tests and diagnostics.
    property int offered: 0

    signal undone(string key)
    signal failed(string key, string reason)

    property var _restore: null
    property int holdMs: 0

    // Record that `title` was just applied and how to put it back.
    // `restore` is `() => bool | string | void`; `detail` is one short line.
    function offer(key: string, title: string, restore: var, detail: string): void {
        if (typeof restore !== "function")
            return;
        if (root.kind === "applied" && root.key === key && root._restore !== null) {
            // Same change continuing: keep the first restore point.
            root.title = title;
            root.detail = detail ?? "";
        } else {
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

    // The apply failed and was reverted by the caller; say why.
    function report(key: string, title: string, why: string): void {
        root.kind = "failed";
        root.key = key;
        root.title = title;
        root.detail = "";
        root.reason = why && why.length > 0 ? why : qsTr("The change was not applied.");
        root._restore = null;
        root._arm(Math.max(root.totalMs, 8000));
        root.failed(key, root.reason);
    }

    // A restore callback for plain config values: remembers `keys` of each
    // `obj` as they are right now and writes them back (then saves once).
    //   Undo.restorer([{obj: Config.bar.sizes, keys: ["innerWidth"]}])
    function restorer(targets: var): var {
        const saved = targets.map(t => ({
                    "obj": t.obj,
                    "values": t.keys.map(k => [k, Array.isArray(t.obj[k]) ? Array.from(t.obj[k]) : t.obj[k]])
                }));
        return () => {
            for (const entry of saved) {
                for (const kv of entry.values)
                    entry.obj[kv[0]] = kv[1];
            }
            Config.save();
            return true;
        };
    }

    function undo(): void {
        if (!root.canUndo)
            return;
        const restore = root._restore;
        const key = root.key;
        const title = root.title;
        root._restore = null;
        let result = true;
        try {
            result = restore();
        } catch (e) {
            result = String(e);
        }
        if (result === false || typeof result === "string") {
            root.report(key, qsTr("Could not undo %1").arg(title), typeof result === "string" ? result : "");
            return;
        }
        root.kind = "undone";
        root.reason = "";
        root._arm(3000);
        root.undone(key);
    }

    function dismiss(): void {
        root.kind = "";
        root.key = "";
        root.title = "";
        root.detail = "";
        root.reason = "";
        root._restore = null;
        root.remainingMs = 0;
        tick.stop();
    }

    function _arm(ms: int): void {
        root.holdMs = ms;
        root.remainingMs = ms;
        tick.restart();
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
}
