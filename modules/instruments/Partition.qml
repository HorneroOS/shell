pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// Partitioned quantity with a dimension line (Signal Bezel §6.4, borrowed
// from Carta): one bar split used / cache / free (`ink`, `inkFaint`,
// empty) and a 1 px `inkFaint` dimension line with 9 px end ticks and
// Plex Mono 11 labels on a `panel` knockout. Shows proportions, never
// motion. `cache` < 0 means the source does not report it.
Item {
    id: root

    property real total: 0
    property real used: 0
    property real cache: -1
    property string usedLabel: ""
    property string cacheLabel: ""
    property string totalLabel: ""
    property color knockout: Signal.palette.panel
    readonly property bool available: total > 0
    readonly property real usedFrac: available ? Math.max(0, Math.min(1, used / total)) : 0
    readonly property real cacheFrac: available && cache > 0 ? Math.max(0, Math.min(1 - usedFrac, cache / total)) : 0

    implicitHeight: bar.height + 6 + dim.height
    implicitWidth: 240

    Rectangle {
        id: bar

        width: parent.width
        height: 12
        color: "transparent"
        border.width: 1
        border.color: Signal.palette.rule
        radius: 1

        Rectangle {
            x: 1
            y: 1
            width: Math.round((bar.width - 2) * root.usedFrac)
            height: bar.height - 2
            color: Signal.palette.ink
        }

        Rectangle {
            x: 1 + Math.round((bar.width - 2) * root.usedFrac)
            y: 1
            width: Math.round((bar.width - 2) * root.cacheFrac)
            height: bar.height - 2
            color: Signal.palette.inkFaint
        }
    }

    // Dimension line across the used span, label centred on a knockout.
    Item {
        id: dim

        anchors.top: bar.bottom
        anchors.topMargin: 6
        width: parent.width
        height: 14

        component Span: Item {
            id: span

            property real from: 0
            property real to: 0
            property string label: ""
            readonly property real px: Math.round(span.from * dim.width)
            readonly property real pw: Math.max(0, Math.round((span.to - span.from) * dim.width))

            visible: label !== "" && pw > 0
            x: px
            width: pw
            height: dim.height

            Rectangle {
                y: Math.round(span.height / 2)
                width: parent.width
                height: 1
                color: Signal.palette.inkFaint
            }
            Rectangle {
                y: Math.round(span.height / 2) - 4
                width: 1
                height: 9
                color: Signal.palette.inkFaint
            }
            Rectangle {
                x: parent.width - 1
                y: Math.round(span.height / 2) - 4
                width: 1
                height: 9
                color: Signal.palette.inkFaint
            }
            Rectangle {
                anchors.centerIn: parent
                width: spanLabel.implicitWidth + 8
                height: spanLabel.implicitHeight
                color: root.knockout
                visible: spanLabel.implicitWidth + 12 < span.width

                StyledText {
                    id: spanLabel

                    anchors.centerIn: parent
                    mono: true
                    text: span.label
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                }
            }
        }

        Span {
            from: 0
            to: root.usedFrac
            label: root.usedLabel
        }

        Span {
            from: root.usedFrac
            to: root.usedFrac + root.cacheFrac
            label: root.cacheLabel
        }
    }
}
