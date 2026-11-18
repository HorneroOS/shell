import QtQuick
import Quickshell
import Quickshell.Io
import "cover.js" as Cover

// The reload cover's view of the user's live state, read once at start
// from the same files the main shell uses (services/Signal.qml,
// config/Config.qml, utils/Paths.qml):
//   ${XDG_STATE_HOME:-~/.local/state}/hornero/signal/scheme.json
//   ${XDG_CONFIG_HOME:-~/.config}/hornero/shell.json
// Read-only. Missing or invalid files resolve to Signal Night with
// default settings (cover.js), so the cover never fails to paint.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`

    readonly property var cover: Cover.resolve(scheme.loaded ? scheme.text() : "", shellConfig.loaded ? shellConfig.text() : "")
    readonly property string lang: Cover.language([Quickshell.env("LANGUAGE"), Quickshell.env("LC_ALL"), Quickshell.env("LC_MESSAGES"), Quickshell.env("LANG"), Qt.locale().name])
    // Screen that carries the full slate: the focused monitor on
    // Hyprland, else the first screen.
    property string primaryName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    // FileView.loaded is false for a missing file; text() is then "".
    FileView {
        id: scheme

        path: `${root.stateHome}/hornero/signal/scheme.json`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: shellConfig

        path: `${root.configHome}/hornero/shell.json`
        blockLoading: true
        printErrors: false
    }

    // One short-lived process; any failure keeps the first screen.
    Process {
        running: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").length > 0
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: root.primaryName = Cover.primaryScreen(text, Quickshell.screens.map(s => s.name))
        }
    }
}
