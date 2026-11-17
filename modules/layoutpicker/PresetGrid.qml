pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Reusable grid of shell layout presets with mini previews.
// Hosts: layoutpicker modal (drawers), controlcenter layout pane
// (the dashboard Layout tab was removed by ADR 003).
// Data comes from `horneroctl shell preset list --full` (enriched JSON:
// name, display, description, lineage, position, style, active, plus the `bars` topology the previews draw);
// applying a preset deep-merges into shell.json and live-reloads
// (no shell restart needed). When horneroctl is missing or the list fails,
// the grid falls back to the empty state with the store path hint below;
// a `current` pointer naming an unknown preset resolves to no selection
// rather than a wrong badge.
Item {
    id: root

    // Keyboard navigation (arrow keys + Enter). Enable only when the host
    // gives this grid exclusive key focus (e.g. the modal picker).
    property bool keyboardNav: false
    // Offer "Applied · Undo" (services/Undo.qml) after a preset applies. The
    // Control Center turns this on; the modal picker has no strip to show it.
    property bool offerUndo: false

    property var presets: []
    property string currentName: ""
    property int focusIndex: 0
    // Width the host can give the grid (0 = unconstrained modal): columns
    // follow it so Settings > Layout and the modal picker both fit.
    property real availableWidth: 0

    readonly property int cardWidth: 212
    readonly property int count: presets.length
    // The preset the catalogue marks active (or null when none matches).
    readonly property var currentPreset: presets.find(p => p.name === currentName) ?? null
    readonly property int columns: {
        const maxCols = availableWidth > 0 ? Math.floor((availableWidth + Appearance.spacing.normal) / (cardWidth + Appearance.spacing.normal)) : (count > 12 ? 5 : 4);
        return Math.max(1, Math.min(maxCols, Math.max(count, 1)));
    }

    // Glyph per preset id. The shell owns its own iconography: the CLI's
    // legacy icon fields are ignored, and unknown (user) presets fall back
    // to the generic layout glyph.
    readonly property var presetGlyphs: ({
            "classic-bottom": "layout-bottombar",
            "classic-top": "layout-navbar",
            "cockpit": "layout-rows",
            "cockpit-clear": "blur",
            "cozy-minimal": "minimize",
            "dock-bottom": "layout-bottombar",
            "floating-island": "app-window",
            "gaming": "device-gamepad-2",
            "horizon": "layout-rows",
            "hornero-left": "layout-sidebar",
            "hornero-right": "layout-sidebar-right",
            "islands": "layout-columns",
            "minimal-left": "layout-sidebar",
            "minimal-top": "minimize",
            "productivity": "briefcase",
            "studio": "music"
        })

    function glyphFor(p: var): string {
        return root.presetGlyphs[p.name] ?? "layout-dashboard";
    }

    // Human topology summary for a card ("Two bars · top + bottom").
    function topologyLabel(p: var): string {
        const bars = Array.from(p.bars ?? []);
        const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
        if (bars.length === 0) {
            const edge = p.position ?? p.edge;
            if (!edge)
                return qsTr("Topology preview unavailable");
            return qsTr("%1 bar").arg(cap(edge));
        }
        const clear = bars.every(b => b.backdrop === "clear") ? qsTr(" · clear") : bars.some(b => b.backdrop === "clear") ? qsTr(" · mixed") : "";
        if (bars.length > 1)
            return cap(bars.map(b => b.edge).join(" + ")) + clear;
        const b = bars[0];
        if (b.edge === "left" || b.edge === "right")
            return qsTr("%1 rail").arg(cap(b.edge)) + clear;
        if (b.style === "dock")
            return qsTr("Dock · %1").arg(b.edge) + clear;
        if (b.style === "islands")
            return qsTr("Islands · %1").arg(b.edge) + clear;
        if (b.style === "floating")
            return qsTr("Floating · %1").arg(b.edge) + clear;
        return qsTr("%1 bar").arg(cap(b.edge)) + clear;
    }

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    function reload(): void {
        listProc.running = true;
    }

    // Preset application is transactional from the user's side: shell.json
    // and the active-preset pointer are copied aside first, one apply runs
    // at a time (a newer choice made meanwhile replaces an older queued one),
    // a failure puts the previous name back and says why, and Undo restores
    // the copied files atomically (copy to a temp file, then rename).
    readonly property string undoRoot: `${Paths.state}/shell/undo`
    property string _target: ""
    property string _prevName: ""
    property string _queued: ""
    property string _snapDir: ""
    property string _failure: ""
    readonly property bool applying: snapProc.running || applyProc.running

    function apply(name: string): void {
        if (name === "")
            return;
        if (root.applying) {
            root._queued = name;
            root.currentName = name;
            return;
        }
        root._begin(name, false);
    }

    // `continuing`: a newer choice made while the previous one was applying.
    // It keeps the FIRST safety copy, so one Undo goes back to where the burst
    // started rather than to an intermediate layout.
    function _begin(name: string, continuing: bool): void {
        root._target = name;
        root._failure = "";
        if (!continuing)
            root._prevName = root.currentName;
        root.currentName = name; // optimistic; the re-list corrects if it failed
        if (continuing) {
            root._startApply();
            return;
        }
        root._snapDir = `${root.undoRoot}/${Date.now()}`;
        snapProc.command = ["sh", "-c", 'set -eu; d="$1"; mkdir -p "$d"; cp -p "$2" "$d/shell.json"; if [ -f "$3" ]; then cp -p "$3" "$d/current-shell-preset"; fi; ls -1dt "$(dirname "$d")"/*/ | tail -n +4 | xargs -r rm -rf', "sh", root._snapDir, `${Paths.config}/shell.json`, `${Paths.state}/current-shell-preset`];
        snapProc.running = true;
    }

    function _startApply(): void {
        applyProc.command = ["horneroctl", "shell", "preset", "apply", root._target, "--yes"];
        applyProc.running = true;
    }

    function _restore(dir: string): void {
        restoreProc.command = ["sh", "-c", 'set -eu; d="$1"; cp -p "$d/shell.json" "$2.undo.tmp"; mv -f "$2.undo.tmp" "$2"; if [ -f "$d/current-shell-preset" ]; then cp -p "$d/current-shell-preset" "$3.undo.tmp"; mv -f "$3.undo.tmp" "$3"; fi', "sh", dir, `${Paths.config}/shell.json`, `${Paths.state}/current-shell-preset`];
        restoreProc.running = true;
    }

    function applyFocused(): void {
        const p = root.presets[root.focusIndex];
        if (p)
            root.apply(p.name);
    }

    function focusCurrentPreset(): void {
        if (!root.keyboardNav)
            return;
        const index = root.presets.findIndex(p => p.name === root.currentName);
        if (index >= 0) {
            root.focusIndex = index;
            // Applying a layout live-rebuilds the bars. Quickshell may move
            // active focus during that reload, so restore it to the picker
            // after the current event and binding updates have settled.
            Qt.callLater(() => {
                if (root.keyboardNav)
                    root.forceActiveFocus();
            });
        }
    }

    onKeyboardNavChanged: focusCurrentPreset()
    onCurrentNameChanged: focusCurrentPreset()

    Component.onCompleted: reload()

    Process {
        id: listProc

        command: ["horneroctl", "shell", "preset", "list", "--full"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    if (!Array.isArray(list))
                        throw new Error("expected a JSON array");
                    root.presets = list;
                    const active = list.find(p => p.active);
                    // Fallback chain: an unknown active pointer (stale
                    // state file, uninstalled preset) selects nothing
                    // instead of badgeing the wrong card.
                    root.currentName = active ? active.name : "";
                    // The list refresh completes after the apply process; by
                    // then the live shell reload may have taken focus again.
                    root.focusCurrentPreset();
                    if (!active)
                        console.warn("[layoutpicker] No active preset in list; selection cleared");
                } catch (e) {
                    console.warn("[layoutpicker] Failed to parse preset list:", e);
                    root.presets = [];
                    root.currentName = "";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                console.warn("[layoutpicker] horneroctl preset list failed (exit", exitCode + "); empty state shown");
                root.presets = [];
                root.currentName = "";
            }
        }
    }

    Process {
        id: snapProc

        stderr: StdioCollector {
            id: snapErr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // No safety copy means no safe apply: stop before changing anything.
                root.currentName = root._prevName;
                Undo.report("layout", qsTr("Layout was not changed"), qsTr("Could not save the current settings first (%1). Nothing was changed.").arg(snapErr.text.trim().split("\n").slice(-1)[0] || qsTr("copy failed")));
                root._next();
                return;
            }
            root._startApply();
        }
    }

    Process {
        id: applyProc

        stdout: StdioCollector {
            onStreamFinished: console.log("[layoutpicker] apply stdout:", text)
        }
        stderr: StdioCollector {
            id: applyErr

            onStreamFinished: console.warn("[layoutpicker] apply stderr:", text)
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[layoutpicker] apply exit", exitCode, exitStatus);
            if (exitCode !== 0) {
                // horneroctl validates before it writes: the old layout is intact.
                const why = applyErr.text.trim().split("\n").slice(-1)[0];
                const target = root.presets.find(p => p.name === root._target);
                root.currentName = root._prevName;
                Undo.report("layout", qsTr("Layout %1 was not applied").arg(target ? target.display : root._target), why || qsTr("horneroctl refused the preset. Your previous layout is unchanged."));
            } else if (root.offerUndo && root._queued === "") {
                const dir = root._snapDir;
                const target = root.presets.find(p => p.name === root._target);
                Undo.offer("layout", qsTr("Layout %1").arg(target ? target.display : root._target), () => {
                    root._restore(dir);
                    return true;
                }, qsTr("Undo brings back the previous layout and its tuning."));
            }
            // Re-sync the active marker from disk (source of truth)
            root.reload();
            root._next();
        }
    }

    Process {
        id: restoreProc

        stderr: StdioCollector {
            id: restoreErr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Undo.report("layout", qsTr("Could not undo the layout"), restoreErr.text.trim().split("\n").slice(-1)[0] || qsTr("The previous settings could not be restored."));
            root.reload();
        }
    }

    // Newest choice wins: one more apply for what was picked while busy.
    function _next(): void {
        const q = root._queued;
        root._queued = "";
        if (q !== "")
            root._begin(q, true);
    }

    focus: root.keyboardNav

    Keys.onLeftPressed: root.focusIndex = (root.focusIndex - 1 + root.count) % root.count
    Keys.onRightPressed: root.focusIndex = (root.focusIndex + 1) % root.count
    Keys.onUpPressed: root.focusIndex = (root.focusIndex - root.columns + root.count) % root.count
    Keys.onDownPressed: root.focusIndex = (root.focusIndex + root.columns) % root.count
    Keys.onTabPressed: root.focusIndex = (root.focusIndex + 1) % root.count
    Keys.onBacktabPressed: root.focusIndex = (root.focusIndex - 1 + root.count) % root.count
    Keys.onReturnPressed: root.applyFocused()
    Keys.onEnterPressed: root.applyFocused()

    GridLayout {
        id: grid

        anchors.centerIn: parent
        columns: root.columns
        rowSpacing: Appearance.spacing.normal
        columnSpacing: Appearance.spacing.normal

        Repeater {
            model: root.presets

            delegate: StyledRect {
                id: card

                required property var modelData
                required property int index

                readonly property bool isActive: modelData.name === root.currentName
                readonly property bool isFocused: root.keyboardNav && index === root.focusIndex

                implicitWidth: root.cardWidth
                implicitHeight: 226
                radius: Appearance.rounding.small
                color: isActive ? Signal.palette.signalWell : Signal.layer(Signal.palette.raised, 1)
                border.color: isFocused ? Signal.palette.focus : isActive ? Signal.palette.signal : Signal.palette.rule
                border.width: isFocused || isActive ? 2 : 1

                FileView {
                    id: specFile

                    readonly property var spec: {
                        try {
                            return JSON.parse(text()).bar.bars;
                        } catch (e) {
                            return [];
                        }
                    }

                    path: Qt.resolvedUrl(`${Quickshell.shellDir}/presets/${card.modelData.name}.json`)
                }

                Behavior on color {
                    CAnim {}
                }

                Behavior on border.color {
                    CAnim {}
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.small

                    LayoutPreview {
                        Layout.alignment: Qt.AlignHCenter
                        bars: card.modelData.bars ?? []
                        // Real geometry and components from the shipped preset
                        // JSON; user presets fall back to the CLI's counts.
                        specs: specFile.spec
                        highlighted: card.isActive || card.isFocused

                        // Current layout badge on the preview corner
                        StyledRect {
                            visible: card.isActive
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            implicitWidth: currentIcon.implicitWidth + 4
                            implicitHeight: currentIcon.implicitHeight + 4
                            radius: Appearance.rounding.small
                            color: Signal.palette.signal

                            Glyph {
                                id: currentIcon

                                anchors.centerIn: parent
                                name: "check"
                                color: Signal.palette.onSignal
                                font.pointSize: Appearance.font.size.small
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Glyph {
                            name: root.glyphFor(card.modelData)
                            color: card.isActive ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: card.modelData.display
                                font.pointSize: Appearance.font.size.normal
                                font.weight: card.isActive ? Font.Medium : Font.Normal
                                color: Signal.palette.ink
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.topologyLabel(card.modelData)
                                font.pointSize: Appearance.font.size.smaller
                                color: card.isActive ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                                elide: Text.ElideRight
                            }

                            // Credit for presets derived from other projects.
                            StyledText {
                                Layout.fillWidth: true
                                visible: (card.modelData.lineage ?? "").length > 0
                                text: qsTr("After %1").arg(card.modelData.lineage ?? "")
                                font.pointSize: Appearance.font.size.small
                                color: card.isActive ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: card.modelData.display
                Accessible.description: root.topologyLabel(card.modelData) + ((card.modelData.lineage ?? "").length > 0 ? ". " + qsTr("After %1").arg(card.modelData.lineage) : "") + (card.isActive ? ". " + qsTr("Current layout") : "")

                StateLayer {
                    radius: card.radius
                    onClicked: {
                        root.focusIndex = card.index;
                        root.apply(card.modelData.name);
                    }
                }
            }
        }
    }

    // Empty state
    StyledText {
        anchors.centerIn: parent
        visible: root.count === 0
        // Presets are package data with user overrides in the Hornero XDG tree.
        text: qsTr("No presets found — check ~/.local/share/hornero/shell-presets")
        color: Signal.palette.inkMuted
    }
}
