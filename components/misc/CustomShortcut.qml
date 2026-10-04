import Quickshell
import Quickshell.Hyprland
import QtQuick

// Quickshell's GlobalShortcut is implemented by the Hyprland-only global
// shortcuts protocol. Keep the Shell's event contract compositor-neutral and
// register that implementation only inside a real Hyprland session. Other
// backends bind their native shortcuts to the Shell's stable IPC handlers.
Item {
    id: root

    property string name
    property string description
    signal pressed()
    signal released()

    Loader {
        active: Quickshell.env("NIRI_SOCKET") === "" && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""

        sourceComponent: GlobalShortcut {
            appid: "hornero"
            name: root.name
            description: root.description
            onPressed: root.pressed()
            onReleased: root.released()
        }
    }
}
