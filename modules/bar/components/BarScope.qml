pragma ComponentBehavior: Bound

import qs.components
import qs.components.misc
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes
import qs.modules.instruments as Instruments

// Bar telemetry scope (Signal experience only, shell#511): a thin
// 1 px trace of real CPU load with a fine tick graticule, sized for the
// 24-28 px bars. It plots only real samples; with none it draws just the
// graticule. The trace is `signal`/tone ink; the optional glow is one
// extra translucent stroke (no offscreen layer), rationed through the
// shell-wide glow budget (visual language §9).
Item {
    id: root

    property var tone: ClearInk.neutral
    property int window: 36
    readonly property real gap: Appearance.spacing.small

    implicitWidth: 56
    implicitHeight: Math.max(10, Density.inner - Appearance.padding.small * 4)

    Ref {
        service: SystemUsage
    }

    Instruments.TraceBuffer {
        id: buffer

        length: root.window
    }

    Timer {
        interval: Math.max(1000, Experience.telemetryIntervalMs)
        running: root.visible && !Experience.telemetryPaused
        repeat: true
        triggeredOnStart: true
        onTriggered: buffer.sample(SystemUsage.cpuPerc)
    }

    property bool _granted: false
    readonly property bool glowWanted: Experience.glow && root.visible && buffer.samples.length > 1
    readonly property bool glowAllowed: root.glowWanted && root._granted
    onGlowWantedChanged: root._syncGlow()
    Component.onCompleted: root._syncGlow()
    Component.onDestruction: Experience.releaseGlow(root)

    function _syncGlow(): void {
        if (root.glowWanted)
            root._granted = Experience.acquireGlow(root, 1);
        else {
            Experience.releaseGlow(root);
            root._granted = false;
        }
    }

    function path(data: var): var {
        const out = [];
        const n = data.length;
        const step = root.width / Math.max(1, root.window - 1);
        const x0 = root.width - (n - 1) * step;
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, data[i]));
            out.push(Qt.point(x0 + i * step, root.height - 1.5 - v * (root.height - 3)));
        }
        return out;
    }

    // Graticule: baseline plus a tick every 8 px, 1 px high.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.alpha(root.tone.inkMuted, 0.45)
    }

    Repeater {
        model: Math.floor(root.width / 8)

        Rectangle {
            required property int index

            x: (index + 1) * 8 - 1
            y: root.height - 4
            width: 1
            height: 3
            color: Qt.alpha(root.tone.inkMuted, 0.4)
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Glow: the same line, wider and translucent, under the trace.
        ShapePath {
            strokeColor: root.glowAllowed ? Qt.alpha(Signal.palette.glow, 0.32) : "transparent"
            strokeWidth: 4
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline {
                path: root.path(buffer.samples)
            }
        }

        ShapePath {
            strokeColor: root.tone.signal
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline {
                path: root.path(buffer.samples)
            }
        }
    }
}
