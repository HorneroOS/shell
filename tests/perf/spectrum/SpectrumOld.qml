import QtQuick

// The pre-SpectrumMeter structure, kept verbatim in shape for the probe:
// the Media tab well (one Repeater of segment meters, each a Repeater of
// Rectangles) and the desktop visualiser (one Rectangle per band per side
// with a 160 ms Behavior on its value).
Item {
    id: root

    property int bands: 45
    property var values: []
    property string parts: "both"

    // Media tab well
    Row {
        visible: root.parts !== "desktop"
        x: 40
        y: 40
        width: 900
        height: 44
        spacing: 2

        Repeater {
            model: root.bands

            Item {
                id: band

                required property int index
                readonly property real level: Math.max(0, Math.min(1, root.values[index] ?? 0))
                readonly property int count: Math.max(1, Math.floor((band.height + 2) / 5))
                readonly property int lit: Math.round(level * count)

                width: Math.max(2, (900 - (root.bands - 1) * 2) / root.bands)
                height: 44

                Repeater {
                    model: band.count

                    Rectangle {
                        required property int index

                        readonly property real segLevel: (index + 1) / band.count
                        readonly property bool on: index < band.lit

                        y: band.height - (index + 1) * 3 - index * 2
                        width: band.width
                        height: 3
                        color: !on ? "#3a332b" : segLevel > 2 ? "#e8a03c" : "#7fd69a"
                    }
                }
            }
        }
    }

    // Desktop visualiser, both sides
    Repeater {
        model: root.parts === "well" ? 0 : 2

        Item {
            id: side

            required property int index
            readonly property bool isRight: index === 1

            anchors.fill: parent

            Repeater {
                model: root.bands

                Rectangle {
                    id: bar

                    required property int modelData
                    property real value: Math.max(0, Math.min(1, root.values[side.isRight ? modelData : root.bands - modelData - 1] ?? 0))

                    x: modelData * ((side.width * 0.4) / root.bands) + (side.isRight ? side.width * 0.6 : 0)
                    width: (side.width * 0.4) / root.bands - 4
                    y: side.height - height
                    height: bar.value * side.height * 0.4
                    color: Qt.alpha("#7fd69a", 0.6)

                    Behavior on value {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                        }
                    }
                }
            }
        }
    }
}
