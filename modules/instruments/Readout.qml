import qs.components
import qs.services
import qs.config
import QtQuick

// Large readout (Signal Bezel §6.3): eyebrow above a `sunken` well with a
// Plex Sans Condensed number and a Plex Mono unit. `value` "" renders an
// em dash in `inkMuted` (unavailable source).
Column {
    id: root

    property string label: ""
    property string value: ""
    property string unit: ""
    property color valueColor: Signal.palette.ink
    property real valueSize: Appearance.font.size.extraLarge * 0.85

    spacing: 6

    Accessible.role: Accessible.StaticText
    Accessible.name: label + ": " + (value !== "" ? value + " " + unit : qsTr("unavailable"))

    Eyebrow {
        label: root.label
    }

    Well {
        width: root.width > 0 ? root.width : implicitWidth
        implicitWidth: row.implicitWidth + 20
        implicitHeight: row.implicitHeight + 8

        Row {
            id: row

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StyledText {
                text: root.value !== "" ? root.value : "—"
                color: root.value !== "" ? root.valueColor : Signal.palette.inkMuted
                font.family: Appearance.font.family.display
                font.weight: Font.Medium
                font.pointSize: root.valueSize
                tabular: true
                font.letterSpacing: -root.valueSize * 0.01
            }

            StyledText {
                anchors.baseline: parent.children[0].baseline
                visible: root.value !== "" && root.unit !== ""
                mono: true
                text: root.unit
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.normal
            }
        }
    }
}
