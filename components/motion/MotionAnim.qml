import QtQuick

// A NumberAnimation timed by a named RFC 0001 §3.6 motion (and therefore
// by the active motion level): `kind` picks the curve and its default
// duration, `speed` optionally overrides the duration token.
//
//   Behavior on x { MotionAnim { kind: "settle" } }
//   Behavior on opacity { MotionAnim { kind: "enter"; speed: "quick" } }
//
// settle/settleFast overshoot slightly and are for position, size and
// shape only; use enter/exit/standard for opacity and colour.
NumberAnimation {
    id: root

    property string kind: "standard"
    property string speed: ""

    readonly property var _defaults: ({
            "standard": "medium",
            "enter": "brief",
            "exit": "quick",
            "sweep": "long",
            "settle": "settle",
            "settleFast": "settleFast"
        })

    duration: Choreography[speed !== "" ? speed : (_defaults[kind] ?? "medium")] ?? Choreography.medium
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Choreography.curves[kind] ?? Choreography.curves.standard
}
