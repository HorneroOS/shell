import qs.components
import qs.config
import QtQuick

Item {
    id: root

    required property var visibilities
    required property Item panels

    visible: height > 0
    // The sidebar only widens the tray when it shares the right edge.
    readonly property bool onRight: Config.notifs.align !== "left" && Config.notifs.align !== "center"
    implicitWidth: onRight ? Math.max(panels.sidebar.width, content.implicitWidth) : content.implicitWidth
    implicitHeight: content.implicitHeight

    states: State {
        name: "hidden"
        when: root.visibilities.sidebar && Config.sidebar.enabled

        PropertyChanges {
            root.implicitHeight: 0
        }
    }

    transitions: Transition {
        Anim {
            target: root
            property: "implicitHeight"
            duration: Appearance.anim.durations.settle
            easing.bezierCurve: Appearance.anim.curves.settle
        }
    }

    Content {
        id: content

        visibilities: root.visibilities
        panels: root.panels
    }
}
