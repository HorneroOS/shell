import qs.services
import QtQuick

// 2 × 10 px `signal` tick on the leading top corner of the focused or
// active panel (RFC 0001 §2). Place it in the panel's top-left corner.
Rectangle {
    property bool vertical: true

    width: vertical ? 2 : 10
    height: vertical ? 10 : 2
    color: Signal.palette.signal
}
