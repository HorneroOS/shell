import qs.components
import qs.components.misc
import qs.services
import qs.config
import QtQuick

Row {
    id: root

    anchors.top: parent.top
    anchors.bottom: parent.bottom

    padding: Appearance.padding.large
    spacing: Appearance.spacing.normal

    Ref {
        service: SystemUsage
    }

    Resource {
        icon: "memory"
        label: qsTr("CPU")
        value: SystemUsage.cpuPerc
        colour: Signal.palette.signal
    }

    Resource {
        icon: "cpu-2"
        label: qsTr("Memory")
        value: SystemUsage.memPerc
        colour: Signal.palette.cue
    }

    Resource {
        icon: "device-sd-card"
        label: qsTr("Storage")
        value: SystemUsage.storagePerc
        colour: Signal.palette.phosphor
    }

    component Resource: Item {
        id: res

        required property string icon
        required property real value
        required property color colour
        required property string label

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large
        implicitWidth: Math.max(icon.implicitWidth, valueText.implicitWidth)

        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("%1 %2%").arg(res.label).arg(Math.round(res.value * 100))

        // The bar alone said nothing (shell#462): the value sits on top of
        // it, in the bar's colour.
        StyledText {
            id: valueText

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: Math.round(res.value * 100) + "%"
            color: res.colour
            font.pointSize: Appearance.font.size.small
            font.weight: 600
        }

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: valueText.bottom
            anchors.topMargin: Appearance.spacing.small
            anchors.bottom: icon.top
            anchors.bottomMargin: Appearance.spacing.small

            implicitWidth: Config.dashboard.sizes.resourceProgessThickness

            color: Signal.layer(Signal.palette.raised, 2)
            radius: Appearance.rounding.full

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: res.value * parent.height

                color: res.colour
                radius: Appearance.rounding.full
            }
        }

        Glyph {
            id: icon

            anchors.bottom: parent.bottom

            name: res.icon
            color: res.colour
        }

        Behavior on value {
            Anim {
                duration: Appearance.anim.durations.long
            }
        }
    }
}
