import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Oscilloscope telemetry, the signature instrument (visual language
// §6.4, §9, §10): a `sunken` well with a 10 × 4 graticule in `rule`, a
// dashed centre line, one 1.5 px `phosphor` trace and the previous
// window drawn at 22 % as persistence (real data, one window old).
//
//   UiScope {
//       label: "CPU · 10 %/DIV"; context: "60 S WINDOW"
//       samples: Telemetry.window("cpu"); previous: Telemetry.previousWindow("cpu")
//   }
//
// In the `signal` experience (dark themes, not high contrast, motion
// allowed) the trace gets the luminous accent — a static 4 px halo at
// 40 % — and the well gets faint static scanlines. Day themes keep the
// persistence (a chart-recorder look) without glow or scanlines.
// `available: false` shows an em dash and `unavailableText` instead of
// any trace: there are no placeholder waves and no idle animation.
Rectangle {
    id: root

    property var samples: []
    property var previous: []
    property real minimum: 0
    property real maximum: 1
    // Samples across the full width.
    property int window: 120
    property string label: ""
    property string context: ""
    property bool available: true
    property string unavailableText: ""
    property string tone: "phosphor"
    property bool glow: true
    property int divisionsX: 10
    property int divisionsY: 4

    readonly property bool _hasTrace: root.available && Array.isArray(root.samples) && root.samples.length >= 2
    readonly property color traceColor: root.tone === "cue" ? Theme.palette.cue : root.tone === "signal" ? Theme.palette.signal : Theme.palette.phosphor
    readonly property bool _wantsGlow: root.glow && Theme.glowEnabled && root._hasTrace && root.visible
    readonly property bool glowing: root._wantsGlow && root._granted
    property bool _granted: false

    implicitWidth: 400
    implicitHeight: 150
    radius: Theme.rounding.small
    color: Theme.palette.sunken
    border.width: 1
    border.color: Theme.palette.rule
    clip: true

    Accessible.role: Accessible.Graphic
    Accessible.name: root.available ? `${root.label} ${root.context}` : `${root.label} unavailable`

    on_WantsGlowChanged: root._syncGlow()
    Component.onCompleted: root._syncGlow()
    // The budget singleton may already be gone during engine teardown.
    Component.onDestruction: {
        if (typeof GlowBudget.release === "function")
            GlowBudget.release(root);
    }

    function _syncGlow(): void {
        if (root._wantsGlow)
            root._granted = GlowBudget.acquire(root);
        else {
            GlowBudget.release(root);
            root._granted = false;
        }
    }

    function _points(values: var, w: real, h: real): var {
        const list = Array.isArray(values) ? values.filter(v => typeof v === "number" && isFinite(v)) : [];
        const n = Math.min(list.length, root.window);
        if (n < 2 || w <= 0 || h <= 0)
            return [];
        const slice = list.slice(list.length - n);
        const span = root.maximum > root.minimum ? root.maximum - root.minimum : 1;
        const step = w / Math.max(1, root.window - 1);
        const x0 = w - (n - 1) * step;
        return slice.map((v, i) => Qt.point(x0 + i * step, h - h * Math.max(0, Math.min(1, (v - root.minimum) / span))));
    }

    // Plot area: inside the 1 px border.
    Item {
        id: plot

        anchors.fill: parent
        anchors.margins: 1

        // Graticule: 10 × 4 divisions in `rule`.
        Repeater {
            model: root.divisionsX - 1

            delegate: Rectangle {
                required property int index

                x: Math.round(plot.width * (index + 1) / root.divisionsX)
                width: 1
                height: plot.height
                color: Theme.palette.rule
            }
        }

        Repeater {
            model: root.divisionsY - 1

            delegate: Rectangle {
                required property int index

                visible: index + 1 !== root.divisionsY / 2
                y: Math.round(plot.height * (index + 1) / root.divisionsY)
                width: plot.width
                height: 1
                color: Theme.palette.rule
            }
        }

        // Centre line, dashed 2/3.
        Shape {
            anchors.fill: parent

            ShapePath {
                strokeColor: Theme.palette.ruleStrong
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]
                fillColor: "transparent"
                startX: 0
                startY: Math.round(plot.height / 2) + 0.5

                PathLine {
                    x: plot.width
                    y: Math.round(plot.height / 2) + 0.5
                }
            }
        }

        // Static scanlines (Signal mode only): 1 px every 3 px, ink 4 %.
        Canvas {
            anchors.fill: parent
            visible: Theme.scanlines
            renderStrategy: Canvas.Cooperative
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible)
                requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Qt.alpha(Theme.palette.ink, 0.04);
                for (let y = 0; y < height; y += 3)
                    ctx.fillRect(0, y, width, 1);
            }
        }

        // Persistence: the previous window at 22 %.
        Shape {
            anchors.fill: parent
            visible: root.available
            opacity: 0.22
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.traceColor
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root._points(root.previous, plot.width, plot.height)
                }
            }
        }

        Shape {
            id: trace

            anchors.fill: parent
            visible: root._hasTrace
            preferredRendererType: Shape.CurveRenderer
            // Luminous accent: a static 4 px halo at 40 % in `glow`,
            // re-rendered only when a new sample arrives. Never pulses.
            layer.enabled: root.glowing
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.palette.glow
                shadowOpacity: Theme.glowAlpha
                blurMax: Theme.glowBlur
                shadowBlur: 1
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                autoPaddingEnabled: true
            }

            ShapePath {
                strokeColor: root.traceColor
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                PathPolyline {
                    path: root._points(root.samples, plot.width, plot.height)
                }
            }
        }

    }

    // Eyebrows inside the well: channel/scale left, window right.
    UiText {
        x: Theme.padding.normal
        y: Theme.padding.small + 2
        role: "eyebrow"
        text: root.label
        visible: text.length > 0
    }

    UiText {
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding.normal
        y: Theme.padding.small + 2
        role: "eyebrow"
        text: root.context
        visible: text.length > 0
    }

    Column {
        anchors.centerIn: parent
        visible: !root.available
        spacing: Theme.spacing.small

        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "readout"
            color: Theme.palette.inkMuted
            text: "—"
        }

        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "caption"
            text: root.unavailableText
            visible: text.length > 0
        }
    }
}
