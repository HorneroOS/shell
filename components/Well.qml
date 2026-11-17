import qs.services
import qs.config
import QtQuick

// Readout well (signal-visual-language §4.1, §6.3): a `sunken` inset with
// a 1 px `rule` border and radius `small`. Values a person adjusts live
// in wells; read-only values do not. `clear` (Cockpit Clear) drops the
// fill and keeps only a 1 px outline in the current ink.
Rectangle {
    id: root

    property bool clear: false
    property color outline: Signal.palette.rule
    property color clearOutline: Signal.palette.ink

    color: root.clear ? "transparent" : Signal.palette.sunken
    border.width: 1
    border.color: root.clear ? Qt.alpha(root.clearOutline, 0.7) : root.outline
    radius: Appearance.rounding.small
}
