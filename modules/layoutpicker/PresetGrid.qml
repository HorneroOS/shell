pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Reusable grid of shell layout presets with mini previews.
// Hosts: layoutpicker modal (drawers), controlcenter layout pane
// (the dashboard Layout tab was removed by ADR 003).
// Data comes from `horneroctl shell preset list --full` (enriched JSON:
// name, display, description, icon, iconMaterial, position, style,
// active, plus the `bars` topology the previews draw);
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

    property var presets: []
    property string currentName: ""
    property int focusIndex: 0
    // Width the host can give the grid (0 = unconstrained modal): columns
    // follow it so Settings > Layout and the modal picker both fit.
    property real availableWidth: 0

    readonly property int cardWidth: 212
    readonly property int count: presets.length
    readonly property int columns: {
        const maxCols = availableWidth > 0 ? Math.floor((availableWidth + Appearance.spacing.normal) / (cardWidth + Appearance.spacing.normal)) : (count > 12 ? 5 : 4);
        return Math.max(1, Math.min(maxCols, Math.max(count, 1)));
    }

    // Human topology summary for a card ("Two bars · top + bottom").
    function topologyLabel(p: var): string {
        const bars = p.bars && p.bars.length > 0 ? Array.from(p.bars) : [
            {
                edge: p.position,
                style: p.style,
                backdrop: "solid"
            }
        ];
        const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
        const clear = bars.every(b => b.backdrop === "clear") ? qsTr(" · clear") : bars.some(b => b.backdrop === "clear") ? qsTr(" · partly clear") : "";
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

    function apply(name: string): void {
        if (applyProc.running)
            return;
        currentName = name; // optimistic; the re-list corrects if it failed
        applyProc.command = ["horneroctl", "shell", "preset", "apply", name, "--yes"];
        console.log("[layoutpicker] apply", name, "via", applyProc.command);
        applyProc.running = true;
    }

    function applyFocused(): void {
        const p = root.presets[root.focusIndex];
        if (p)
            root.apply(p.name);
    }

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
        id: applyProc

        stdout: StdioCollector {
            onStreamFinished: console.log("[layoutpicker] apply stdout:", text)
        }
        stderr: StdioCollector {
            onStreamFinished: console.warn("[layoutpicker] apply stderr:", text)
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[layoutpicker] apply exit", exitCode, exitStatus);
            // Re-sync the active marker from disk (source of truth)
            root.reload();
        }
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
                implicitHeight: 178
                radius: Appearance.rounding.normal
                color: isActive ? Colours.layer(Colours.palette.m3secondaryContainer, 2) : Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                border.color: isFocused ? Colours.palette.m3primary : isActive ? Colours.palette.m3secondary : Qt.alpha(Colours.palette.m3outline, 0.25)
                border.width: isFocused || isActive ? 2 : 1

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
                        position: card.modelData.position
                        barStyle: card.modelData.style
                        highlighted: card.isActive || card.isFocused

                        // Current layout badge on the preview corner
                        StyledRect {
                            visible: card.isActive
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            implicitWidth: currentIcon.implicitWidth + 4
                            implicitHeight: currentIcon.implicitHeight + 4
                            radius: Appearance.rounding.full
                            color: Colours.palette.m3primary

                            MaterialIcon {
                                id: currentIcon

                                anchors.centerIn: parent
                                text: "check"
                                color: Colours.palette.m3onPrimary
                                font.pointSize: Appearance.font.size.small
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        MaterialIcon {
                            text: card.modelData.iconMaterial || "widgets"
                            color: card.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: card.modelData.display
                                font.pointSize: Appearance.font.size.normal
                                font.weight: card.isActive ? Font.Medium : Font.Normal
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.topologyLabel(card.modelData)
                                font.pointSize: Appearance.font.size.smaller
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: card.modelData.display
                Accessible.description: root.topologyLabel(card.modelData) + (card.isActive ? ". " + qsTr("Current layout") : "")

                StateLayer {
                    radius: card.radius
                    onClicked: {
                        root.focusIndex = card.index;
                        root.apply(card.modelData.name);
                    }
                    onEntered: root.focusIndex = card.index
                }
            }
        }
    }

    // Empty state
    StyledText {
        anchors.centerIn: parent
        visible: root.count === 0
        // Path contract row 2: canonical hornero/* first, legacy dots/* fallback.
        text: qsTr("No presets found — check ~/.local/share/hornero/shell-presets")
        color: Colours.palette.m3onSurfaceVariant
    }
}
