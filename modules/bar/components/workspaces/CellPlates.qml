pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// One plate per workspace cell, drawn under the active mark and the cell
// content, so every state is the same rounded rectangle at the cell's own
// size: empty draws nothing, occupied is a quiet plate, active (when no
// sliding indicator is shown) the signal-tinted plate, urgent an alert
// hairline with one gentle pulse. Never drawn on Cockpit Clear.
Item {
    id: root

    // Region tone: the plain Signal palette.
    property var tone: ClearInk.neutral

    required property Repeater workspaces
    // The strip's cell layout: plates follow its cells.
    required property Item cells
    // Draw the active cell as a plate here (no sliding ActiveIndicator).
    property bool markActive: false
    // The active plate: signal-tinted so it reads at a glance (shared with
    // ActiveIndicator).
    readonly property color activeFill: Qt.tint(Signal.palette.raised, Qt.alpha(root.tone.signal, 0.3))

    Repeater {
        model: root.workspaces.count

        Rectangle {
            id: plate

            required property int index
            readonly property Item cell: root.workspaces.count > 0 ? root.workspaces.itemAt(index) : null
            readonly property bool active: root.markActive && (cell?.isActive ?? false)
            readonly property bool urgent: cell?.isUrgent ?? false
            readonly property bool occupied: cell?.isOccupied ?? false

            visible: !!cell
            x: root.cells.x + (cell?.x ?? 0)
            y: root.cells.y + (cell?.y ?? 0)
            width: cell?.width ?? 0
            height: cell?.height ?? 0
            radius: Appearance.rounding.small

            // Empty cells draw nothing (just the muted numeral); visible-elsewhere
            // is a small mark drawn by the cell, not an outline.
            color: active ? root.activeFill : occupied ? Signal.layer(Signal.palette.raised, 2) : "transparent"
            border.width: urgent ? 1 : 0
            border.color: urgent ? root.tone.alert : "transparent"

            onUrgentChanged: {
                if (urgent && !Appearance.anim.reduced)
                    pulse.restart();
            }

            // One gentle pulse when a workspace turns urgent (never looping,
            // never under reduced motion).
            Rectangle {
                id: flash

                anchors.fill: parent
                radius: parent.radius
                color: root.tone.alert
                opacity: 0

                SequentialAnimation {
                    id: pulse

                    NumberAnimation {
                        target: flash
                        property: "opacity"
                        to: 0.35
                        duration: Appearance.anim.durations.medium
                    }
                    NumberAnimation {
                        target: flash
                        property: "opacity"
                        to: 0
                        duration: Appearance.anim.durations.long
                    }
                }
            }

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
