import qs.config
import QtQuick

NumberAnimation {
    duration: Appearance.anim.durations.medium
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.standard
}
