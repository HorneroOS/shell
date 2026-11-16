pragma Singleton

import Quickshell
import QtQuick
import qs.services

// Typed shell actions for bar components (docs/LAYOUTS.md). Layout presets
// name an action id, never a command string; the shell owns what it does.
Singleton {
    id: root

    readonly property var known: ({
            launcher: {
                icon: "apps",
                label: qsTr("Launcher")
            },
            layoutPicker: {
                icon: "layout-dashboard",
                label: qsTr("Layouts")
            },
            settings: {
                icon: "settings",
                label: qsTr("Settings")
            },
            screenshot: {
                icon: "crop",
                label: qsTr("Screenshot")
            },
            dashboard: {
                icon: "layout-dashboard",
                label: qsTr("Dashboard")
            },
            session: {
                icon: "power",
                label: qsTr("Session")
            }
        })

    // Module-owned surfaces handle these (services never import modules):
    // Shortcuts opens Settings, AreaPicker starts a capture.
    signal settingsRequested
    signal screenshotRequested

    function isKnown(id: string): bool {
        return Object.prototype.hasOwnProperty.call(known, id);
    }

    function run(id: string): void {
        const v = Visibilities.getForActive();
        switch (id) {
        case "launcher":
            v.launcher = !v.launcher;
            break;
        case "layoutPicker":
            v.layoutPicker = !v.layoutPicker;
            break;
        case "dashboard":
            v.dashboard = !v.dashboard;
            break;
        case "session":
            v.session = !v.session;
            break;
        case "settings":
            root.settingsRequested();
            break;
        case "screenshot":
            if (Compositor.supports("nativeScreenshotSelection"))
                Compositor.openScreenshotPicker();
            else
                root.screenshotRequested();
            break;
        default:
            console.warn(`[ShellActions] unknown action "${id}"`);
        }
    }
}
