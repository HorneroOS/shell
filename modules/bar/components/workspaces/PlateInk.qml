pragma ComponentBehavior: Bound

import qs.components
import qs.services
import QtQuick

// Ink-through: a second copy of the numerals in `ink`, clipped to the
// active plate's rect and drawn over the strip, so a numeral turns ink
// exactly where the plate covers it, even mid-flight. A plain clip (no
// MultiEffect, no layer), so it costs no offscreen texture.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral
    // Special workspace open: the copy dims with the rest of the strip.
    property bool receded: false

    // The ActiveIndicator (null while its Loader is inactive) and that Loader.
    required property Item plate
    required property Item plateHost
    required property Repeater workspaces
    // The strip's cell layout (the numerals' parent cells live in it).
    required property Item cells

    visible: !!plate
    clip: true
    x: plateHost.x + (plate?.x ?? 0)
    y: plateHost.y + (plate?.y ?? 0)
    width: plate?.width ?? 0
    height: plate?.height ?? 0

    Repeater {
        model: root.workspaces.count

        StyledText {
            required property int index
            readonly property Item cell: root.workspaces.itemAt(index)
            readonly property Item numeral: cell?.numeral ?? null

            visible: !!numeral && (cell?.visible ?? false)
            // Pixel-aligned with the cell's own numeral, in this clip's frame.
            x: root.cells.x + (cell?.x ?? 0) + (numeral?.x ?? 0) - root.x
            y: root.cells.y + (cell?.y ?? 0) + (numeral?.y ?? 0) - root.y
            width: numeral?.width ?? 0
            height: numeral?.height ?? 0
            scale: numeral?.scale ?? 1
            text: numeral?.text ?? ""
            font: numeral?.font ?? Qt.font({})
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            color: root.receded ? root.tone.inkMuted : root.tone.ink
        }
    }
}
