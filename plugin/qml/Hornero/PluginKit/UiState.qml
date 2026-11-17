import QtQuick

// Empty / loading / error / unavailable states, Signal style: a glyph
// in `inkMuted` (or `alert` for errors) over one short line. Nothing
// animates. `unavailable` is for a source that does not exist on this
// machine (no battery, no GPU sensor): say what is missing.
//
//   kind: "empty" | "loading" | "error" | "unavailable"
Column {
    id: root

    property string kind: "empty"
    property string message: ""
    // Optional override; defaults per kind.
    property string glyph: ""

    spacing: Theme.spacing.small

    Accessible.role: Accessible.StaticText
    Accessible.name: root.message

    UiIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.glyph.length > 0 ? root.glyph : root.kind === "loading" ? "hourglass" : root.kind === "error" ? "alert-triangle" : root.kind === "unavailable" ? "plug-off" : "info-circle"
        size: Theme.font.size.large
        color: root.kind === "error" ? Theme.palette.alert : Theme.palette.inkMuted
    }

    UiText {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.parent && root.parent.width > 0 ? Math.min(implicitWidth, root.parent.width) : implicitWidth
        text: root.message
        role: root.kind === "error" ? "body" : "caption"
        color: root.kind === "error" ? Theme.palette.alert : Theme.palette.inkMuted
        horizontalAlignment: Text.AlignHCenter
    }
}
