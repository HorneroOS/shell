import Quickshell.Io

// Experience mode preferences (RFC 0001 §5a). The active mode itself is
// state, not a preference: it lives in $XDG_STATE_HOME/hornero/experience.json
// (services/Experience.qml, docs/IPC.md). Factory profiles live in
// services/experience.js; this object only stores what the user changed.
JsonObject {
    // Per-mode customisations: { "<mode>": { "<field>": value } } using the
    // dotted field names of services/experience.js FIELDS. Values equal to
    // the factory profile are dropped on save; unknown keys are ignored.
    property var modes: ({})
    // Toast when the mode changes (migrated from the retired
    // utilities.toasts.gameModeChanged).
    property bool toasts: true
    property Auto auto: Auto {}
    // Signal instrument deck overrides per mode (services/deck.js):
    // hidden {mode: [pluginId]} and geometry {mode: {screen: {pluginId:
    // {fx, fy, width, height}}}}. Written only when the person turns a
    // widget off or moves/resizes one; a deck reset removes them.
    property var deck: ({})

    component Auto: JsonObject {
        // Local-only automatic switching: reads the focused window's app id
        // and fullscreen state, nothing else.
        property bool fullscreenGaming: true
        // App id regular expressions treated as games; empty uses the
        // built-in list (Steam app windows, Gamescope, Windows .exe).
        property list<string> gamePatterns: []
    }
}
