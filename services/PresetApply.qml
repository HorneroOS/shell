pragma Singleton

import qs.config
import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Applying a shell layout preset from the Control Center, transactionally
// (docs/CONTROL-CENTER-APPLY.md). Lives in a singleton so the Undo it offers
// keeps working after the Layout pane is unloaded or the window closes.
//
//   1. Safety copy: shell.json and the active-preset pointer are copied to
//      $XDG_STATE_HOME/hornero/shell/undo/<ms>/. A file that does not exist
//      yet (fresh account) is recorded with an `.absent` marker instead.
//   2. `horneroctl shell preset apply <name> --yes`, then the person's saved
//      tweaks for that layout go back on top (Layouts.reapplyAfterPreset).
//   3. Once those settled, the hash of shell.json is recorded. Undo restores
//      the copy (temp file + rename, or removal for an `.absent` file) only
//      if shell.json still has that hash; if anything else changed it since,
//      Undo refuses and says why instead of rolling those changes back too.
//
// One job at a time (snapshot, apply or restore). A newer choice made while
// one runs replaces any older queued one and continues the same burst, so
// a single Undo goes back to where the burst started.
Singleton {
    id: root

    readonly property string undoRoot: `${Paths.state}/shell/undo`
    readonly property string shellJson: `${Paths.config}/shell.json`
    readonly property string pointer: `${Paths.state}/current-shell-preset`
    readonly property bool applying: snapProc.running || applyProc.running || restoreProc.running || hashProc.running

    // Emitted after every apply or restore; hosts re-list from disk.
    signal finished(bool ok, string name)

    property string _target: ""
    property string _display: ""
    property bool _offer: false
    property var _queued: null
    property string _snapDir: ""
    // The snapshot the live offer points to; pruning never removes it.
    property string _offerDir: ""
    // Hash of shell.json after the apply settled ("" while still settling).
    property string _expectHash: ""
    property bool _hashPending: false

    // `display` names the layout in the strip; `offerUndo` false for callers
    // with no strip (the modal picker).
    function apply(name: string, display: string, offerUndo: bool): void {
        if (name === "")
            return;
        const job = {
            "name": name,
            "display": display || name,
            "offer": offerUndo
        };
        if (root.applying) {
            root._queued = job;
            return;
        }
        root._begin(job, false);
    }

    function _begin(job: var, continuing: bool): void {
        root._target = job.name;
        root._display = job.display;
        root._offer = job.offer;
        if (continuing && root._snapDir !== "") {
            root._startApply();
            return;
        }
        root._snapDir = `${root.undoRoot}/${Date.now()}`;
        snapProc.command = ["sh", "-c", 'set -eu; d="$1"; mkdir -p "$d"; '
            + 'if [ -f "$2" ]; then cp -p "$2" "$d/shell.json"; else : > "$d/shell.json.absent"; fi; '
            + 'if [ -f "$3" ]; then cp -p "$3" "$d/current-shell-preset"; else : > "$d/current-shell-preset.absent"; fi; '
            + 'for x in $(ls -1dt "$(dirname "$d")"/*/ | tail -n +4); do x="${x%/}"; [ "$x" = "$d" ] || [ "$x" = "$4" ] || rm -rf "$x"; done',
            "sh", root._snapDir, root.shellJson, root.pointer, root._offerDir || "-"];
        snapProc.running = true;
    }

    function _startApply(): void {
        applyProc.command = ["horneroctl", "shell", "preset", "apply", root._target, "--yes"];
        applyProc.running = true;
    }

    // Newest queued choice: continues the burst after a good apply, starts a
    // fresh one (with its own safety copy) after a failure.
    function _next(continuing: bool): void {
        const q = root._queued;
        root._queued = null;
        if (q)
            root._begin(q, continuing);
    }

    function _restore(dir: string, expect: string): var {
        if (root.applying || root._hashPending)
            return Undo.busy;
        restoreProc.command = ["sh", "-c", 'set -eu; d="$1"; '
            + 'if [ -f "$2" ]; then cur=$(sha256sum "$2" | cut -c1-64); else cur=absent; fi; '
            + 'if [ "$cur" != "$4" ]; then echo "changed" >&2; exit 3; fi; '
            + 'if [ -f "$d/shell.json.absent" ]; then rm -f "$2"; else cp -p "$d/shell.json" "$2.undo.tmp"; mv -f "$2.undo.tmp" "$2"; fi; '
            + 'if [ -f "$d/current-shell-preset.absent" ]; then rm -f "$3"; elif [ -f "$d/current-shell-preset" ]; then cp -p "$d/current-shell-preset" "$3.undo.tmp"; mv -f "$3.undo.tmp" "$3"; fi',
            "sh", dir, root.shellJson, root.pointer, expect];
        restoreProc.running = true;
        return true;
    }

    Process {
        id: snapProc

        stderr: StdioCollector {
            id: snapErr
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                // No safety copy means no safe apply: stop before changing anything.
                root._snapDir = "";
                Undo.report("layout", qsTr("Layout was not changed"), qsTr("Could not save the current settings first (%1). Nothing was changed.").arg(snapErr.text.trim().split("\n").slice(-1)[0] || qsTr("copy failed")));
                root.finished(false, root._target);
                root._next(false);
                return;
            }
            root._startApply();
        }
    }

    Process {
        id: applyProc

        stderr: StdioCollector {
            id: applyErr
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                // horneroctl validates before it writes: the old layout is intact.
                const why = applyErr.text.trim().split("\n").slice(-1)[0];
                Undo.report("layout", qsTr("Layout %1 was not applied").arg(root._display), why || qsTr("horneroctl refused the preset. Your previous layout is unchanged."));
                root.finished(false, root._target);
                root._next(false);
                return;
            }
            // Lay the person's saved tweaks for this layout back on top.
            Layouts.reapplyAfterPreset(root._target);
            if (root._offer && root._queued === null) {
                const dir = root._snapDir;
                // A second layout inside the same Undo window coalesces onto the
                // first restore point: keep protecting that copy.
                if (!(Undo.kind === "applied" && Undo.key === "layout"))
                    root._offerDir = dir;
                root._expectHash = "";
                root._hashPending = true;
                Undo.offer("layout", qsTr("Layout %1").arg(root._display), () => root._restore(dir, root._expectHash), qsTr("Undo brings back the previous layout and its tuning."));
                settle.restart();
            }
            root.finished(true, root._target);
            if (root._queued !== null)
                root._next(true);
            else
                root._snapDir = "";
        }
    }

    // Tweaks re-apply after Layouts.settleMs and Config saves 500 ms later;
    // only then is shell.json the state Undo would replace.
    Timer {
        id: settle

        interval: Layouts.settleMs + 900
        onTriggered: hashProc.running = true
    }

    Process {
        id: hashProc

        command: ["sh", "-c", 'if [ -f "$1" ]; then sha256sum "$1" | cut -c1-64; else echo absent; fi', "sh", root.shellJson]
        stdout: StdioCollector {
            id: hashOut
        }
        onExited: exitCode => {
            root._expectHash = exitCode === 0 ? hashOut.text.trim() : "";
            root._hashPending = false;
        }
    }

    Process {
        id: restoreProc

        stderr: StdioCollector {
            id: restoreErr
        }
        onExited: exitCode => {
            if (exitCode === 3)
                Undo.report("layout", qsTr("Layout was not undone"), qsTr("Other settings changed after the layout was applied, and Undo would have rolled them back too. Pick the previous layout again instead."));
            else if (exitCode !== 0)
                Undo.report("layout", qsTr("Could not undo the layout"), restoreErr.text.trim().split("\n").slice(-1)[0] || qsTr("The previous settings could not be restored."));
            root.finished(exitCode === 0, "");
            root._next(false);
        }
    }
}
