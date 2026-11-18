pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.misc
import qs.services
import qs.config
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Keybinding overlay (COMPETITIVE gap #5). Summoned by the factory
// SUPER + / bind (`horneroctl hardware keyboard keys` toggles it over
// IPC), the `keybinds` IPC target or the `hornero:keybinds` global
// shortcut. Shows every active bind, live from Hyprland, grouped by
// purpose with Hornero Glyphs; filter-as-you-type in English or
// Spanish; Enter runs the highlighted bind; Ctrl+E rebinds it in place
// (press the new combo, conflicts are named before saving, Swap is one
// key away), Ctrl+D disables it and Ctrl+Z undoes the last change. The
// summon key is an ordinary bind: rebind it here like any other.
Scope {
    id: root

    property bool open: false
    property string initialQuery: ""

    function show(query: string): void {
        if (Compositor.hasFullscreenOnFocusedOutput())
            return;
        root.initialQuery = query ?? "";
        Keybinds.refresh();
        root.open = true;
    }

    function hide(): void {
        Keybinds.endCapture();
        root.open = false;
    }

    function toggle(): void {
        if (root.open)
            root.hide();
        else
            root.show("");
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            root.toggle();
        }

        function open(query: string): void {
            root.show(query);
        }

        function close(): void {
            root.hide();
        }

        function isOpen(): bool {
            return root.open;
        }
    }

    Connections {
        target: Keybinds

        function onOverlayRequested(query: string): void {
            root.show(query);
        }
    }

    CustomShortcut {
        name: "keybinds"
        description: "Toggle the keybinding overlay"
        onPressed: root.toggle()
    }

    Timer {
        id: runLater

        property var entry: null

        interval: 120
        onTriggered: Keybinds.run(runLater.entry)
    }

    LazyLoader {
        active: root.open

        StyledWindow {
            id: win

            name: "keybinds"
            screen: Quickshell.screens.find(s => s.name === Compositor.focusedOutputName) ?? Quickshell.screens[0]
            // Top, not Overlay: a fullscreen game always covers shell surfaces
            // (tests/test_gaming_focus_contract.py); show() refuses under one.
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Signal.palette.scrim, 0.55)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.hide()
                }
            }

            KeybindsSheet {
                anchors.centerIn: parent
                width: Math.min(980, win.width - 48)
                height: Math.min(760, win.height - 64)
                initialQuery: root.initialQuery
                onCloseRequested: root.hide()
                onRunRequested: entry => {
                    runLater.entry = entry;
                    root.hide();
                    runLater.restart();
                }
            }
        }
    }
}
