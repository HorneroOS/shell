import QtQuick

// Native state layer for PluginKit controls: the same overlay the shell's
// StateLayer draws. A tinted layer at 8% on hover, 12% while pressed, and a
// press ripple that expands from the contact point (standardDecel) and fades.
// The host control owns hover/press tracking and passes it in, so it can be
// placed under any control's own mouse handling without stealing events.
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool disabled: false
    property real radius: 0
    property color color: Theme.onSurface

    // Press point in this item's coordinates; the ripple starts here.
    property real pressX: width / 2
    property real pressY: height / 2

    clip: true

    Rectangle {
        id: overlay

        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        opacity: root.disabled ? 0 : root.pressed ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : 0
        // Native StateLayer colour is the control colour at full alpha; the
        // opacity above carries the 8% / 12% level.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.color
        }
    }

    Rectangle {
        id: ripple

        property real diameter: 0

        radius: width / 2
        color: root.color
        opacity: 0
        width: diameter
        height: diameter
        x: root.pressX - width / 2
        y: root.pressY - height / 2
    }

    SequentialAnimation {
        id: rippleAnim

        running: false

        ParallelAnimation {
            NumberAnimation {
                target: ripple
                property: "diameter"
                from: 0
                to: root.farthestCornerDiameter()
                duration: Theme.durationNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveStandardDecel
            }
            NumberAnimation {
                target: ripple
                property: "opacity"
                from: Theme.stateHoverOpacity
                to: 0
                duration: Theme.durationNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveStandard
            }
        }
    }

    // Diameter that covers the whole control from the press point.
    function farthestCornerDiameter(): real {
        const dx = Math.max(root.pressX, root.width - root.pressX);
        const dy = Math.max(root.pressY, root.height - root.pressY);
        return 2 * Math.sqrt(dx * dx + dy * dy);
    }

    // Call on a press: restarts the ripple from (x, y).
    function startRipple(x: real, y: real): void {
        if (root.disabled || Theme.reducedMotion)
            return;
        root.pressX = x;
        root.pressY = y;
        rippleAnim.restart();
    }
}
