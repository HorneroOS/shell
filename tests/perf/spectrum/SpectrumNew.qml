import QtQuick
import Hornero.Internal

// The same two users drawn by SpectrumMeter (one item per spectrum).
Item {
    id: root

    property int bands: 45
    property var values: []
    property string parts: "both"

    SpectrumMeter {
        visible: root.parts !== "desktop"
        x: 40
        y: 40
        width: 900
        height: 44
        values: root.values
        offColor: "#3a332b"
        hotThreshold: 2
        peakHold: false
    }

    SpectrumMeter {
        visible: root.parts !== "well"
        x: 0
        y: root.height * 0.6
        width: root.width * 0.4
        height: root.height * 0.4
        values: root.values
        reversed: true
        segment: 0
        bandGap: 4
        peakHold: false
        hotThreshold: 2
        onColor: Qt.alpha("#7fd69a", 0.6)
    }

    SpectrumMeter {
        visible: root.parts !== "well"
        x: root.width * 0.6
        y: root.height * 0.6
        width: root.width * 0.4
        height: root.height * 0.4
        values: root.values
        segment: 0
        bandGap: 4
        peakHold: false
        hotThreshold: 2
        onColor: Qt.alpha("#7fd69a", 0.6)
    }
}
