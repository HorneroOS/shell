import qs.services
import QtQuick

// 1 px separator. `vertical` draws a column (between bar segments), else
// a row (between panel sections). `strong` uses `ruleStrong` for control
// boundaries that must pass 3:1.
Rectangle {
    id: root

    property bool vertical: false
    property bool strong: false

    color: root.strong ? Signal.palette.ruleStrong : Signal.palette.rule
    implicitWidth: root.vertical ? 1 : 0
    implicitHeight: root.vertical ? 0 : 1

    Accessible.ignored: true
}
