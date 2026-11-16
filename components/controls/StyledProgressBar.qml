import QtQuick
import qs.components
import qs.services
import qs.config
import QtQuick.Templates

ProgressBar {
    id: root

    property bool wavy: false
    property real waveFrequency: 5
    property real waveAmplitude: 2
    property color fgColour: Signal.palette.signal
    property color bgColour: Signal.palette.lifted

    implicitHeight: 6
    implicitWidth: 200

    background: StyledRect {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.implicitHeight
        radius: 0
        color: root.bgColour
    }

    contentItem: Item {
        StyledRect {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.position * parent.width
            height: root.implicitHeight
            radius: 0
            color: root.fgColour
        }
    }

    Behavior on value {
        Anim {}
    }
}
