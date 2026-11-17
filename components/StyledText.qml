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
    // Typography polish (visual language section 17.4): readouts and clocks
    // set `tabular` for fixed-width figures (OpenType tnum), so changing
    // digits never shift their neighbours; tracking is tuned per call site
    // (display sizes read better a hair tighter: set `font.letterSpacing` to
    // a small negative fraction of the point size at the call site).
    property bool tabular: false
    font.features: root.tabular ? ({
            "tnum": 1
        }) : ({})
    font.pointSize: Appearance.font.size.smaller
    font.weight: Appearance.font.weight.regular

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
