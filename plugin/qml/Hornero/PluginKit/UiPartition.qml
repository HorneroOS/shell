import QtQuick

// Partition bar with a dimension line (visual language §6.4, borrowed
// from Carta): one bar split into used / secondary / free (`ink`,
// `inkFaint`, empty) with a 1 px `inkFaint` dimension line underneath,
// 9 px end ticks and Plex Mono labels on a knockout. Partitions show
// proportions, not motion.
//
//   UiPartition { total: 32; used: 11.2; secondary: 6.1
//                 usedLabel: "used"; secondaryLabel: "cache" }
Item {
    id: root

    property real total: 0
    property real used: 0
    property real secondary: 0
    property string usedLabel: ""
    property string secondaryLabel: ""
    property bool available: true
    // Knockout colour behind the labels: the surface this sits on.
    property color knockout: Theme.palette.panel

    readonly property bool _shown: root.available && root.total > 0
    readonly property real _usedFrac: root._shown ? Math.max(0, Math.min(1, root.used / root.total)) : 0
    readonly property real _secondaryFrac: root._shown ? Math.max(0, Math.min(1 - root._usedFrac, root.secondary / root.total)) : 0

    implicitWidth: 200
    implicitHeight: bar.height + 6 + dim.height

    Accessible.role: Accessible.ProgressBar
    Accessible.name: root._shown ? `${root.usedLabel} ${Math.round(root._usedFrac * 100)} %` : "unavailable"

    Rectangle {
        id: bar

        width: parent.width
        height: 8
        radius: 1
        color: "transparent"
        border.width: 1
        border.color: Theme.palette.rule

        Rectangle {
            x: 1
            y: 1
            width: Math.max(0, (parent.width - 2) * root._usedFrac)
            height: parent.height - 2
            color: Theme.palette.ink
        }

        Rectangle {
            x: 1 + (parent.width - 2) * root._usedFrac
            y: 1
            width: Math.max(0, (parent.width - 2) * root._secondaryFrac)
            height: parent.height - 2
            color: Theme.palette.inkFaint
        }
    }

    // Dimension line: |—— used ——|—— cache ——|
    Item {
        id: dim

        anchors.top: bar.bottom
        anchors.topMargin: 6
        width: parent.width
        height: 14
        visible: root._shown

        DimensionSpan {
            x: 0
            width: bar.width * root._usedFrac
            label: root.usedLabel
        }

        DimensionSpan {
            x: bar.width * root._usedFrac
            width: bar.width * root._secondaryFrac
            label: root.secondaryLabel
        }
    }

    component DimensionSpan: Item {
        id: span

        property string label: ""
        readonly property bool showLabel: span.label.length > 0 && spanLabel.implicitWidth + 12 < span.width

        height: dim.height
        visible: width >= 12

        Rectangle {
            width: 1
            height: 9
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.inkFaint
        }

        Rectangle {
            x: span.width - 1
            width: 1
            height: 9
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.inkFaint
        }

        Rectangle {
            width: span.width
            height: 1
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.inkFaint
        }

        Rectangle {
            anchors.centerIn: parent
            width: spanLabel.implicitWidth + 8
            height: spanLabel.implicitHeight
            color: root.knockout
            visible: span.showLabel

            UiText {
                id: spanLabel

                anchors.centerIn: parent
                role: "value"
                font.pointSize: Theme.font.size.small
                color: Theme.palette.inkMuted
                text: span.label
            }
        }
    }
}
