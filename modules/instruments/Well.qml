import qs.components
import qs.services
import qs.config
import QtQuick

// Sunken readout well (Signal Bezel §4.1, §6.3): `sunken` fill, 1 px
// `rule` border, radius `small`.
StyledRect {
    color: Signal.palette.sunken
    radius: Appearance.rounding.small
    border.width: 1
    border.color: Signal.palette.rule
}
