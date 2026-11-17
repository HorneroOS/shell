import QtQuick
import Hornero.PluginKit

// Bar indicator: a small glyph that hints the commands exist. The
// commands themselves live in Commands.qml, which the shell loads on the
// first invocation of a command (launcher `>do`, IPC, key binding).
Item {
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    UiIcon {
        id: icon

        name: "bolt"
        color: Theme.palette.inkMuted
    }
}
