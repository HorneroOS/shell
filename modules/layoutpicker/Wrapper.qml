pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import QtQuick

// Centered modal panel hosting the shell layout picker.
// Toggled via `visibilities.layoutPicker` (IPC: `drawers toggle layoutPicker`).
Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels

    readonly property real nonAnimWidth: content.item?.implicitWidth ?? 0
    readonly property real nonAnimHeight: content.item?.implicitHeight ?? 0

    visible: width > 0 && height > 0
    implicitWidth: 0
    implicitHeight: 0

    states: State {
        name: "visible"
        when: root.visibilities.layoutPicker

        PropertyChanges {
            root.implicitWidth: root.nonAnimWidth
            root.implicitHeight: root.nonAnimHeight
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                properties: "implicitWidth,implicitHeight"
                duration: Appearance.anim.durations.settle
                easing.bezierCurve: Appearance.anim.curves.settle
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                properties: "implicitWidth,implicitHeight"
                duration: Appearance.anim.durations.medium
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    ]

    Loader {
        id: content

        anchors.centerIn: parent

        Component.onCompleted: active = Qt.binding(() => root.visibilities.layoutPicker || root.visible)

        sourceComponent: Content {
            visibilities: root.visibilities
        }
    }
}
