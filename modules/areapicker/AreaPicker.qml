pragma ComponentBehavior: Bound

import qs.components.containers
import qs.components.misc
import qs.modules.companion
import qs.services
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    LazyLoader {
        id: root

        property bool freeze
        property bool closing
        property bool clipboardOnly

        // The companion suppresses itself while the picker owns the
        // screen (see CompanionStore.areaPickerOpen).
        onActiveChanged: CompanionStore.areaPickerOpen = active

        Variants {
            model: Quickshell.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "area-picker"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: root.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                Picker {
                    loader: root
                    screen: win.modelData
                }
            }
        }
    }

    Connections {
        target: ShellActions

        function onScreenshotRequested(): void {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }
    }

    IpcHandler {
        target: "picker"

        function open(): void {
            if (Compositor.supports("nativeScreenshotSelection")) {
                Compositor.openScreenshotPicker();
                return;
            }
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }

        function openFreeze(): void {
            if (Compositor.supports("nativeScreenshotSelection")) {
                console.warn("[Screenshot] Frozen capture is unavailable in Niri; opening its native picker.");
                Compositor.openScreenshotPicker();
                return;
            }
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }

        function openClip(): void {
            if (Compositor.supports("nativeScreenshotSelection")) {
                Compositor.openScreenshotPicker();
                return;
            }
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }

        function openFreezeClip(): void {
            if (Compositor.supports("nativeScreenshotSelection")) {
                console.warn("[Screenshot] Frozen capture is unavailable in Niri; opening its native picker.");
                Compositor.openScreenshotPicker();
                return;
            }
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshot"
        description: "Open screenshot tool"
        onPressed: {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshotFreeze"
        description: "Open screenshot tool (freeze mode)"
        onPressed: {
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = false;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshotClip"
        description: "Open screenshot tool (clipboard)"
        onPressed: {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "screenshotFreezeClip"
        description: "Open screenshot tool (freeze mode, clipboard)"
        onPressed: {
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = true;
            root.activeAsync = true;
        }
    }
}
