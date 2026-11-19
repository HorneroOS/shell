import Quickshell.Io

// Keybinding overlay (SUPER + /) and Control Center > Keybinds.
// The summon key itself is a normal bind: rebind it in the overlay.
JsonObject {
    property Overlay overlay: Overlay {}
    property SuperHold superHold: SuperHold {}

    component Overlay: JsonObject {
        // Enter runs the highlighted bind (Omarchy SUPER + K parity).
        property bool runOnEnter: true
        // Close the overlay after running a bind.
        property bool closeAfterRun: true
        // List submap binds (resize mode, gaps mode, overview).
        property bool showSubmaps: true
        // List mouse binds (SUPER + drag).
        property bool showMouse: true
        // Denser rows: more binds per screen.
        property bool compact: false
    }

    // Holding bare SUPER shows key badges on the bar workspaces
    // (HorneroOS/shell#701). Detection binds are non-consuming, so
    // turning this off only stops the shell from reacting to them.
    component SuperHold: JsonObject {
        property bool enabled: true
        // Canonical: config/ranges.json (keybinds.superHold.holdMs).
        property int holdMs: 600
    }
}
