import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Inline sparkline (visual language §6.4): 18–24 px tall, 1.5 px stroke,
// no fill, no axes. Tones: `cue` for network, `phosphor` for load,
// `signal` for temperature. Plot real samples only; between two samples
// the line is straight, nothing is interpolated or invented. Fewer than
// two samples draws nothing. Print the current value beside it.
//
//   UiSparkline { values: Telemetry.series("netDown"); tone: "cue" }
Item {
    id: root

    property var values: []
    // Fixed scale; maximum <= minimum means "auto" (largest sample).
    property real minimum: 0
    property real maximum: 1
    // Samples across the full width (older samples scroll off).
    property int window: 60
    property string tone: "phosphor"
    // Ask for the luminous accent (granted only in the `signal`
    // experience and within the three-item budget).
    property bool glow: false
    property string accessibleName: ""

    readonly property color strokeColor: root.tone === "cue" ? Theme.palette.cue : root.tone === "signal" ? Theme.palette.signal : root.tone === "alert" ? Theme.palette.alert : Theme.palette.phosphor
    readonly property bool _wantsGlow: root.glow && Theme.glowEnabled && root.visible
    readonly property bool glowing: root._wantsGlow && root._granted
    property bool _granted: false

    implicitWidth: 120
    implicitHeight: 20

    Accessible.role: Accessible.Graphic
    Accessible.name: root.accessibleName

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
        const n = Math.min(list.length, Math.max(2, root.window));
        if (n < 2 || w <= 0 || h <= 0)
            return [];
        const slice = list.slice(list.length - n);
        let lo = root.minimum;
        let hi = root.maximum;
        if (hi <= lo) {
            hi = Math.max(...slice);
            lo = Math.min(lo, Math.min(...slice));
            if (hi <= lo)
                hi = lo + 1;
        }
        const step = w / Math.max(1, root.window - 1);
        const x0 = w - (n - 1) * step;
        const inset = 1;
        return slice.map((v, i) => Qt.point(x0 + i * step, inset + (h - inset * 2) * (1 - Math.max(0, Math.min(1, (v - lo) / (hi - lo))))));
    }

    Shape {
        id: trace

        anchors.fill: parent
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
            strokeColor: root.strokeColor
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: root._points(root.values, root.width, root.height)
            }
        }
    }

}
