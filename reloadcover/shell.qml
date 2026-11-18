pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Reload cover: a standalone quickshell config (`qs --path
// <conf>/reloadcover/shell.qml`) that paints every screen while
// `horneroctl shell restart` swaps the main shell underneath.
// Deliberately dependency-free (no shell modules, only Quickshell
// built-ins and files in this directory): it must load even when the
// main config is broken. The orchestrator kills this process by PID
// after the new shell is up; a 60 s watchdog quits it anyway so a failed
// restart can never leave a permanent cover.
//
// Look: a Hornero Signal stand-by slate (Slate.qml) in the user's live
// palette and settings (CoverState.qml reads scheme.json and shell.json
// read-only; missing or invalid files fall back to Signal Night).
ShellRoot {
    id: root

    readonly property var cover: live.cover
    property int elapsed: 0

    CoverState {
        id: live
    }

    // The only clock: elapsed seconds for the timecode readout, Javi's
    // slow doze frames and the "taking longer" hint.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.elapsed++
    }

    // Safety net: never cover the desktop forever.
    Timer {
        interval: 60000
        running: true
        repeat: false
        onTriggered: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hornero-reload-cover"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            color: root.cover.palette.ground

            Slate {
                anchors.fill: parent
                cover: root.cover
                lang: live.lang
                motion: !live.cover.reducedMotion
                elapsed: root.elapsed
                primary: win.modelData.name === live.primaryName
                screenName: win.modelData.name
            }
        }
    }
}
