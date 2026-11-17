pragma ComponentBehavior: Bound

import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// The signature instrument (Signal Bezel §6.4): a `sunken` well with a
// 10 × 4 graticule, dashed centre line, one 1.5 px trace and the previous
// window as 22 % persistence. Plots only real samples; with none it shows
// an empty graticule. `glow` (≤ 40 % alpha, ≤ 4 px) is opt-in for the
// Signal experience and is ignored in light/high-contrast themes.
Well {
    id: root

    property var samples: []
    property var persistence: []
    property int window: 60
    property real maxValue: 1
    property color traceColor: Signal.palette.phosphor
    property bool glow: false
    property bool scanlines: false
    readonly property bool glowWanted: glow && !Signal.light && !Config.appearance.highContrast && root.visible && samples.length > 1
    // Glow is rationed shell-wide (visual language §9): a trace without a
    // lease renders the same line without the halo.
    property bool _granted: false
    readonly property bool glowAllowed: root.glowWanted && root._granted
    onGlowWantedChanged: root._syncGlow()
    Component.onCompleted: root._syncGlow()
    Component.onDestruction: Experience.releaseGlow(root)

    function _syncGlow(): void {
        if (root.glowWanted)
            root._granted = Experience.acquireGlow(root, 0);
        else {
            Experience.releaseGlow(root);
            root._granted = false;
        }
    }

    clip: true

    function points(data: var, w: real, h: real): var {
        const out = [];
        const n = data.length;
        if (n === 0)
            return out;
        const step = w / Math.max(1, root.window - 1);
        const x0 = w - (n - 1) * step;
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(root.maxValue, data[i])) / root.maxValue;
            out.push(Qt.point(x0 + i * step, h - 1 - v * (h - 2)));
        }
        return out;
    }

    // Graticule: 10 × 4 divisions in `rule`.
    Repeater {
        model: 9

        Rectangle {
            required property int index

            x: Math.round((index + 1) * root.width / 10)
            width: 1
            height: root.height
            color: Signal.palette.rule
            opacity: 0.7
        }
    }

    Repeater {
        model: 3

        Item {
            id: hline

            required property int index
            readonly property bool centre: index === 1

            y: Math.round((index + 1) * root.height / 4)
            width: root.width
            height: 1

            Rectangle {
                visible: !hline.centre
                anchors.fill: parent
                color: Signal.palette.rule
                opacity: 0.7
            }

            // Centre line dashed 2/3.
            Row {
                visible: hline.centre
                spacing: 3

                Repeater {
                    model: Math.ceil(root.width / 5)

                    Rectangle {
                        width: 2
                        height: 1
                        color: Signal.palette.ruleStrong
                    }
                }
            }
        }
    }

    // Static scanlines (Signal mode only): 1 px every 3 px, ink at 4 %.
    Column {
        visible: root.scanlines && !Signal.light
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.scanlines ? Math.ceil(root.height / 3) : 0

            Rectangle {
                width: root.width
                height: 1
                color: Qt.alpha(Signal.palette.ink, 0.04)
            }
        }
    }

    Shape {
        id: shape

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(root.traceColor, 0.22)
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.points(root.persistence, shape.width, shape.height)
            }
        }

        ShapePath {
            strokeColor: root.glowAllowed ? Qt.alpha(Signal.palette.glow, 0.35) : "transparent"
            strokeWidth: 5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: root.glowAllowed ? root.points(root.samples, shape.width, shape.height) : []
            }
        }

        ShapePath {
            strokeColor: root.traceColor
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: root.points(root.samples, shape.width, shape.height)
            }
        }
    }
}
