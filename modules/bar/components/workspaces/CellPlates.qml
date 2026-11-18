pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// One plate per workspace cell, drawn under the active mark and the cell
// content, so every state is the same rounded rectangle at the cell's own
// size: empty is a hairline, occupied a quiet plate, active (when no sliding
// indicator is shown) the raised plate, urgent an alert hairline and
// visible-elsewhere a strong hairline. Never drawn on Cockpit Clear.
Item {
    id: root

    // Region tone: the plain Signal palette.
    property var tone: ClearInk.neutral

    required property Repeater workspaces
    // The strip's cell layout: plates follow its cells.
    required property Item cells
    // Draw the active cell as a plate here (no sliding ActiveIndicator).
    property bool markActive: false

    Repeater {
        model: root.workspaces.count

        Rectangle {
            id: plate

            required property int index
            readonly property Item cell: root.workspaces.count > 0 ? root.workspaces.itemAt(index) : null
            readonly property bool active: root.markActive && (cell?.isActive ?? false)
            readonly property bool urgent: cell?.isUrgent ?? false
            readonly property bool elsewhere: cell?.isVisibleElsewhere ?? false
            readonly property bool occupied: cell?.isOccupied ?? false

            visible: !!cell
            x: root.cells.x + (cell?.x ?? 0)
            y: root.cells.y + (cell?.y ?? 0)
            width: cell?.width ?? 0
            height: cell?.height ?? 0
            radius: Appearance.rounding.small

            color: active ? Qt.tint(Signal.palette.raised, Qt.alpha(root.tone.ink, 0.1)) : occupied ? Signal.layer(Signal.palette.raised, 2) : "transparent"
            border.width: active ? 0 : 1
            border.color: urgent ? root.tone.alert : elsewhere ? Signal.palette.ruleStrong : occupied ? "transparent" : Signal.palette.rule

            Behavior on color {
                CAnim {}
            }

            Behavior on border.color {
                CAnim {}
            }

            Behavior on x {
                Anim {}
            }

            Behavior on width {
                Anim {}
            }
        }
    }
}
