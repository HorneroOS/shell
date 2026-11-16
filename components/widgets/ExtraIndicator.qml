import ".."
import "../effects"
import qs.services
import qs.config
import QtQuick

StyledRect {
    required property int extra

    anchors.right: parent.right
    anchors.margins: Appearance.padding.normal

    color: Signal.palette.phosphor
    radius: Appearance.rounding.small

    implicitWidth: count.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: count.implicitHeight + Appearance.padding.small * 2

    opacity: extra > 0 ? 1 : 0
    scale: extra > 0 ? 1 : 0.5

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 2
    }

    StyledText {
        id: count

        anchors.centerIn: parent
        animate: parent.opacity > 0
        text: qsTr("+%1").arg(parent.extra)
        color: Signal.palette.onPhosphor
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.settleFast
        }
    }

    Behavior on scale {
        Anim {
            duration: Appearance.anim.durations.settleFast
            easing.bezierCurve: Appearance.anim.curves.settleFast
        }
    }
}
