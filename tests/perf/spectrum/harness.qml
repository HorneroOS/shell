import QtQuick
import QtQuick.Window
import Hornero.Services

// Spectrum idle/playing CPU probe (see run-spectrum-cpu.py). Draws the two
// spectrum users at once, as with the Media tab open over the desktop
// visualiser: a 45-band segmented well plus the two desktop columns.
//   args: <old|new> <idle|play> [bands] [both|well|desktop]
//   idle  real CavaProvider on the default sink monitor (nothing playing)
//   play  synthetic 86 Hz values (the cava frame rate), no sampler
Window {
    id: win

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string impl: args[0] ?? "new"
    readonly property string scenario: args[1] ?? "idle"
    readonly property int bands: parseInt(args[2] ?? "45")
    // both | well | desktop: which of the two users to draw.
    readonly property string parts: args[3] ?? "both"
    property var values: new Array(bands).fill(0)
    property real t: 0

    width: 1280
    height: 720
    visible: true
    color: "#16130f"

    CavaProvider {
        id: cava

        bars: win.bands
    }

    ServiceRef {
        service: win.scenario === "idle" ? cava : null
    }

    Timer {
        running: win.scenario === "play"
        interval: 11
        repeat: true
        onTriggered: {
            win.t += 0.011;
            const v = [];
            for (let i = 0; i < win.bands; i++) {
                const base = Math.exp(-i / (win.bands * 0.45));
                const wobble = 0.5 + 0.5 * Math.sin(win.t * (3 + i * 0.37) + i);
                const kick = Math.max(0, Math.sin(win.t * 8.1)) ** 6;
                v.push(Math.min(1, base * (0.35 + 0.55 * wobble) + kick * 0.3 * base));
            }
            win.values = v;
        }
    }

    Loader {
        anchors.fill: parent
        source: win.impl === "old" ? "SpectrumOld.qml" : "SpectrumNew.qml"
        onLoaded: {
            item.bands = win.bands;
            item.parts = win.parts;
            item.values = Qt.binding(() => win.scenario === "idle" ? cava.values : win.values);
        }
    }

    // Frames actually presented, logged every 5 s (both variants render on
    // demand, so this shows how often each one makes the window redraw).
    property int swaps: 0

    onFrameSwapped: swaps++

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            console.log("SPECTRUM_FPS", (win.swaps / 5).toFixed(1));
            win.swaps = 0;
        }
    }

    Component.onCompleted: console.log("SPECTRUM_PROBE_READY", impl, scenario, bands)
}
