pragma Singleton

import "keybinds.js" as Model
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Keybindings service shared by the keybinding overlay (SUPER + /) and
// Control Center > Keybinds. Reads every active bind through
// `horneroctl hardware keyboard rebind list --json` (live from Hyprland,
// with the config's category and action) and rebinds through
// `rebind set|reset|undo`, which write the config-owned overlay
// (~/.config/hypr/hornero-keybinds.lua) and reload Hyprland. Factory
// and personal keybinding files are never edited.
Singleton {
    id: root

    property var entries: []
    property bool live: false
    property bool managed: false
    property bool isLua: false
    property bool loading: false
    property bool loaded: false
    property int overrides: 0
    property int undoDepth: 0
    property string file: ""
    property string error: ""

    // Last write: message, success, and a conflict the backend refused.
    property bool busy: false
    property string lastMessage: ""
    property bool lastOk: true
    property var lastConflict: null

    readonly property var settings: Model.settings(Config.keybinds.overlay)
    readonly property string summonCombo: Model.summonCombo(entries)

    signal refreshed
    // A set/reset/undo finished: `what` is the caller's one-line summary.
    signal written(bool ok, string message, string what, var undoArgv)
    signal overlayRequested(string query)

    // Open the keybinding overlay (from Control Center, Welcome, plugins).
    function openOverlay(query: string): void {
        root.overlayRequested(query ?? "");
    }

    function grouped(query: string): var {
        return Model.grouped(root.entries, query, root.settings);
    }

    function flatten(groups: var): var {
        return Model.flatten(groups);
    }

    function conflictFor(combo: string, moving: string): var {
        return Model.conflictFor(root.entries, combo, moving);
    }

    function comboFromKey(key: int, modifiers: int): string {
        return Model.comboFromKey(key, modifiers);
    }

    function refresh(): void {
        if (listProc.running)
            return;
        root.loading = true;
        listProc.out = "";
        listProc.running = true;
        statusProc.out = "";
        statusProc.running = true;
    }

    function rebind(oldCombo: string, newCombo: string, swap: bool): void {
        const cmd = ["horneroctl", "hardware", "keyboard", "rebind", "set", "--old", oldCombo, "--new", newCombo, "--yes", "--json"];
        if (swap)
            cmd.splice(9, 0, "--swap");
        // Lua sessions undo through the CLI snapshots (exact, swaps
        // included); hyprlang configs undo by moving the bind back.
        const inverse = root.isLua ? root.undoArgv : (swap ? [] : ["horneroctl", "hardware", "keyboard", "rebind", "set", "--old", newCombo, "--new", oldCombo, "--yes", "--json"]);
        root.write(cmd, swap ? qsTr("%1 swapped with %2").arg(oldCombo).arg(newCombo) : qsTr("%1 now %2").arg(oldCombo).arg(newCombo), inverse);
    }

    function disable(combo: string): void {
        root.write(["horneroctl", "hardware", "keyboard", "rebind", "set", "--old", combo, "--new", "none", "--yes", "--json"], qsTr("%1 disabled").arg(combo), root.undoArgv);
    }

    function reset(): void {
        root.write(["horneroctl", "hardware", "keyboard", "rebind", "reset", "--yes", "--json"], qsTr("Keybindings reset to defaults"), root.isLua ? root.undoArgv : []);
    }

    function undo(): void {
        root.write(["horneroctl", "hardware", "keyboard", "rebind", "undo", "--yes", "--json"], qsTr("Last keybinding change undone"), []);
    }

    // The argv that reverts the last write (the CLI keeps the snapshots).
    readonly property var undoArgv: ["horneroctl", "hardware", "keyboard", "rebind", "undo", "--yes", "--json"]

    function write(cmd: var, what: string, inverse: var): void {
        if (root.busy)
            return;
        writeProc.what = what ?? "";
        writeProc.inverse = inverse ?? [];
        root.busy = true;
        root.lastConflict = null;
        root.lastMessage = qsTr("Applying…");
        writeProc.out = "";
        writeProc.command = cmd;
        writeProc.running = true;
    }

    // Run a bind exactly as the compositor would. Lua sessions go through
    // the config's registry (hornero_keybinds.run); hyprlang sessions can
    // only run exec binds.
    function run(entry: var): bool {
        if (!entry || entry.submap !== "")
            return false;
        if (root.managed && root.isLua) {
            Quickshell.execDetached(["hyprctl", "eval", Model.runExpression(entry)]);
            return true;
        }
        const cmd = Model.execCommand(entry);
        if (cmd === "")
            return false;
        Quickshell.execDetached(["sh", "-c", cmd]);
        return true;
    }

    // While capturing a new combo, park Hyprland in the config's empty
    // `hornero_capture` submap so already-bound combos reach the overlay
    // instead of firing. Escape there resets the submap (non-consuming).
    function beginCapture(): void {
        if (root.isLua)
            Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.submap(\"hornero_capture\"))"]);
    }

    function endCapture(): void {
        if (root.isLua)
            Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.submap(\"reset\"))"]);
    }

    Process {
        id: listProc

        property string out: ""

        command: ["env", "HORNERO_BYPASS_QUICKSHELL=1", "horneroctl", "hardware", "keyboard", "rebind", "list", "--json"]
        stdout: SplitParser {
            onRead: data => listProc.out += data
        }
        onExited: (exitCode, exitStatus) => {
            root.loading = false;
            root.loaded = true;
            try {
                const payload = JSON.parse(listProc.out.trim());
                const d = payload.data ?? {};
                if (!payload.ok) {
                    root.error = (payload.message ?? "").toString();
                    root.entries = [];
                    return;
                }
                root.entries = Model.normalise(d.entries ?? "[]");
                root.live = (d.live ?? "false") === "true";
                root.error = "";
            } catch (e) {
                root.entries = [];
                root.error = qsTr("horneroctl keybindings are unavailable on this system.");
            }
            root.refreshed();
        }
    }

    Process {
        id: statusProc

        property string out: ""

        command: ["horneroctl", "hardware", "keyboard", "rebind", "status", "--json"]
        stdout: SplitParser {
            onRead: data => statusProc.out += data
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const d = JSON.parse(statusProc.out.trim()).data ?? {};
                root.managed = (d.managed ?? "false") === "true";
                root.isLua = (d.format ?? "") === "lua";
                root.overrides = parseInt(d.overrides ?? "0") || 0;
                root.undoDepth = parseInt(d.undo ?? "0") || 0;
                root.file = (d.file ?? "").toString();
            } catch (e) {
                root.managed = false;
                root.isLua = false;
                root.overrides = 0;
                root.undoDepth = 0;
            }
        }
    }

    Process {
        id: writeProc

        property string out: ""
        property string what: ""
        property var inverse: []

        stdout: SplitParser {
            onRead: data => writeProc.out += data
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            try {
                const payload = JSON.parse(writeProc.out.trim());
                const d = payload.data ?? {};
                root.lastOk = payload.ok === true;
                root.lastMessage = (payload.message ?? "").toString();
                root.lastConflict = (!payload.ok && d.conflict) ? {
                    combo: d.conflict,
                    action: d.conflict_action ?? "",
                    category: d.conflict_category ?? ""
                } : null;
            } catch (e) {
                root.lastOk = false;
                root.lastMessage = qsTr("horneroctl rebind is unavailable on this system.");
            }
            root.written(root.lastOk, root.lastMessage, writeProc.what, writeProc.inverse);
            // Hyprland reloads asynchronously; read back after it settles.
            readback.restart();
        }
    }

    Timer {
        id: readback

        interval: 350
        onTriggered: root.refresh()
    }
}
