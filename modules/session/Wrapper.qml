pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels
    readonly property real nonAnimWidth: content.implicitWidth

    visible: width > 0
    implicitWidth: 0
    implicitHeight: content.implicitHeight

    states: State {
        name: "visible"
        when: root.visibilities.session && Config.session.enabled

        PropertyChanges {
            root.implicitWidth: root.nonAnimWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
                easing.bezierCurve: Appearance.anim.curves.settle
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                easing.bezierCurve: root.panels.osd.width > 0 ? Appearance.anim.curves.settle : Appearance.anim.curves.standard
            }
        }
    ]

    AtmosphereTexture {}

    Loader {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        Component.onCompleted: active = Qt.binding(() => (root.visibilities.session && Config.session.enabled) || root.visible)

        sourceComponent: Content {
            visibilities: root.visibilities
        }
    }

    // Atmosphere: warm lamp, soft inner light, vignette, grain (section 17).
    AtmosphereLayer {
        lampOrigin: "left"
        lampReach: 0.9
        cornerRadius: Appearance.rounding.small
    }
}
