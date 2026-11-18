pragma ComponentBehavior: Bound

import qs.services
import QtQuick

// Dimension breaks: where the strip skips workspace numbers (1, 2, 5) a
// short broken dimension line sits in the widened gap before the next
// cell, like the break mark on a technical drawing: a 1 px inkFaint line,
// broken in the middle, with 2 px end ticks either side of it. Context by
// drawing convention, not by an extra label. Foreground only, so it is the
// same on Cockpit Clear.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral
    property bool vertical: false

    required property Repeater workspaces
    // The strip's cell layout and its spacing between cells.
    required property Item cells
    property real spacing: 0

    // Clear region tones carry no inkFaint: their muted ink stands in.
    readonly property color ink: root.tone.inkFaint ?? (root.tone.active ? root.tone.inkMuted : Signal.palette.inkFaint)

    Repeater {
        model: root.workspaces.count

        Item {
            id: mark

            required property int index
            readonly property Item cell: root.workspaces.itemAt(index)
            readonly property real space: cell?.breakSpace ?? 0
            // Main-axis span of the widened gap before this cell.
            readonly property real span: space + root.spacing

            visible: !!cell && cell.visible && cell.gapBefore
            x: root.vertical ? root.cells.x + (cell?.x ?? 0) : root.cells.x + (cell?.x ?? 0) - span
            y: root.vertical ? root.cells.y + (cell?.y ?? 0) - span : root.cells.y + (cell?.y ?? 0)
            width: root.vertical ? (cell?.width ?? 0) : span
            height: root.vertical ? span : (cell?.height ?? 0)

            // Mark extent along the bar, inside the gap with 1 px air each end.
            readonly property real len: Math.max(4, Math.round(span - 2))
            readonly property real lead: Math.round((span - len) / 2)
            readonly property real mid: Math.round((root.vertical ? width : height) / 2)

            // Two half-lines with a 2 px break between them.
            Repeater {
                model: 2

                Rectangle {
                    required property int index
                    readonly property real half: Math.max(1, Math.floor((mark.len - 2) / 2))

                    x: root.vertical ? mark.mid : mark.lead + (index === 0 ? 0 : mark.len - half)
                    y: root.vertical ? mark.lead + (index === 0 ? 0 : mark.len - half) : mark.mid
                    width: root.vertical ? 1 : half
                    height: root.vertical ? half : 1
                    color: root.ink
                }
            }

            // End ticks: 1 px wide, reaching 2 px either side of the line.
            Repeater {
                model: 2

                Rectangle {
                    required property int index

                    x: root.vertical ? mark.mid - 2 : mark.lead + (index === 0 ? 0 : mark.len - 1)
                    y: root.vertical ? mark.lead + (index === 0 ? 0 : mark.len - 1) : mark.mid - 2
                    width: root.vertical ? 5 : 1
                    height: root.vertical ? 1 : 5
                    color: root.ink
                }
            }
        }
    }
}
