import QtQuick

// Opacity cross-fade that survives every motion level: `enter` (or `exit`
// when `leaving`) at its normal duration, capped at 90 ms when motion is
// off (RFC 0001 §3.6 reduced motion).
NumberAnimation {
    property bool leaving: false

    property: "opacity"
    duration: leaving ? Choreography.fade : Choreography.fadeIn
    easing.type: Easing.BezierSpline
    easing.bezierCurve: leaving ? Choreography.curves.exit : Choreography.curves.enter
}
