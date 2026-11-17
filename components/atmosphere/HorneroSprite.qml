pragma ComponentBehavior: Bound

import qs.services
import qs.config
import QtQuick

// The hornero, as a small pixel sprite (visual language section 17.2).
// Drawn once from a character grid in palette colours, so it follows every
// theme: back and tail in `lamp`-warmed signal, belly in `inkMuted`, a
// `blush` cheek, the beak in `signal`. Integer pixel size keeps it crisp;
// it blinks now and then unless motion is reduced.
//
// Decorative: hidden from assistive technology. Hidden entirely when the
// user turns the mascot off (Atmosphere.mascot) unless `force` is set.
Item {
    id: root

    property int pixel: 3
    property bool force: false
    // Pose: "perch" (default) or "sleep" (closed eye, for quiet states).
    property string pose: "perch"
    property bool blinkNow: false

    readonly property var rows: [
        "....bbbb........",
        "...bbbbbb.......",
        "..bbbbbbbb......",
        "..bbbEbbbbkk....",
        "..bbbbbbbbkkk...",
        "..bbbPbbbbk.....",
        ".wbbbbbbbbc.....",
        "wwbbbbbbbccc....",
        "wwwbbbbbbcccc...",
        ".wwwbbbbbccc....",
        "..wwbbbbbcc.....",
        "...tbbbbbc......",
        "....t.l.l.......",
        "tttttttttttttttt"
    ]
    readonly property int cols: 16

    readonly property bool shown: root.force || Atmosphere.mascot
    readonly property color cBack: Qt.tint(Signal.palette.signal, Qt.alpha(Signal.palette.alert, 0.32))
    readonly property var palette: ({
            "b": cBack,
            "w": Qt.darker(cBack, 1.35),
            "t": Qt.darker(cBack, 1.15),
            "c": Signal.light ? Qt.tint(Signal.palette.panel, Qt.alpha(Signal.palette.signal, 0.3)) : Signal.palette.ink,
            "k": Signal.palette.signal,
            "E": Signal.palette.ground,
            "P": Atmosphere.blush,
            "l": Signal.palette.inkMuted
        })

    implicitWidth: root.cols * root.pixel
    implicitHeight: root.rows.length * root.pixel
    visible: root.shown
    Accessible.ignored: true

    Timer {
        // A slow blink every ~7 s; never when motion is off.
        interval: 7000
        running: root.shown && root.visible && !Appearance.anim.reduced && root.pose === "perch"
        repeat: true
        onTriggered: {
            root.blinkNow = true;
            blinkEnd.restart();
        }
    }
    Timer {
        id: blinkEnd
        interval: 140
        onTriggered: root.blinkNow = false
    }

    readonly property bool eyeClosed: root.pose === "sleep" || root.blinkNow
    onEyeClosedChanged: canvas.requestPaint()

    Connections {
        target: Signal
        function onPaletteRevisionChanged(): void {
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        renderTarget: Canvas.Image
        antialiasing: false
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const px = root.pixel;
            for (let y = 0; y < root.rows.length; y++) {
                const row = root.rows[y];
                for (let x = 0; x < row.length; x++) {
                    let ch = row[x];
                    if (ch === ".")
                        continue;
                    let colour = root.palette[ch];
                    if (ch === "E" && root.eyeClosed)
                        colour = root.palette["b"];
                    ctx.fillStyle = colour;
                    ctx.fillRect(x * px, y * px, px, px);
                }
            }
            if (root.eyeClosed) {
                ctx.fillStyle = root.palette["E"];
                ctx.fillRect(5 * px, 3 * px + px * 0.5, px, Math.max(1, px * 0.4));
            }
        }
        Component.onCompleted: requestPaint()
    }

    Component.onCompleted: canvas.requestPaint()
    onShownChanged: canvas.requestPaint()
}
