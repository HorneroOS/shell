pragma ComponentBehavior: Bound

import qs.services
import qs.config
import QtQuick

Text {
    id: root

    property bool animate: false
    property string animateProp: "scale"
    property real animateFrom: 0
    property real animateTo: 1
    property int animateDuration: Appearance.anim.durations.medium

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Signal.palette.ink
    // Typeface switch kept here (not at call sites) so the welcome
    // static scans keep their font-family discipline: keycap legends
    // and other data read mono via `mono: true`.
    property bool mono: false
    font.family: root.mono ? Appearance.font.family.mono : Appearance.font.family.sans
    font.pointSize: Appearance.font.size.smaller

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                to: root.animateFrom
                easing.bezierCurve: Appearance.anim.curves.exit
            }
            PropertyAction {}
            Anim {
                to: root.animateTo
                easing.bezierCurve: Appearance.anim.curves.enter
            }
        }
    }

    component Anim: NumberAnimation {
        target: root
        property: root.animateProp
        duration: root.animateDuration / 2
        easing.type: Easing.BezierSpline
    }
}
