import QtQuick
import QtQuick.Window
import Hornero.Internal

// Offscreen probe for SpectrumMeter (tests/test_spectrum_meter.py).
// Phase 1 plays a fixed spectrum and grabs a frame; phase 2 goes silent and
// checks that the meter settles and then stops stepping and painting.
// args: <out.png>
Window {
    id: win

    readonly property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    property var report: ({})

    width: 200
    height: 120
    visible: true
    color: "black"

    Item {
        id: stage

        anchors.fill: parent

        SpectrumMeter {
            id: meter

            x: 10
            y: 10
            width: 180
            height: 100
            // 4 bands: full, half, quiet, silent.
            values: [1.0, 0.5, 0.2, 0.0]
            segment: 3
            segmentGap: 2
            bandGap: 10
            onColor: "#00ff00"
            hotColor: "#ff0000"
            peakColor: "#0000ff"
            hotThreshold: 0.85
        }

        SpectrumMeter {
            id: still

            x: 0
            y: 0
            width: 10
            height: 10
            animated: false
            values: [0.5, 0.25]
        }
    }

    function log(key, value) {
        report[key] = value;
    }

    SequentialAnimation {
        running: true

        PauseAnimation { duration: 800 }
        ScriptAction {
            script: {
                win.log("playingSettled", meter.settled);
                stage.grabToImage(r => r.saveToFile(win.out));
            }
        }
        PauseAnimation { duration: 200 }
        ScriptAction {
            script: {
                meter.values = [0, 0, 0, 0];
                win.log("framesAtSilence", meter.frames);
            }
        }
        PauseAnimation { duration: 3500 }
        ScriptAction {
            script: {
                win.log("silentSettled", meter.settled);
                win.log("framesSettled", meter.frames);
                win.log("paintsSettled", meter.paints);
            }
        }
        PauseAnimation { duration: 1500 }
        ScriptAction {
            script: {
                win.log("framesLater", meter.frames);
                win.log("paintsLater", meter.paints);
                win.log("stillFrames", still.frames);
                win.log("stillSettled", still.settled);
                console.log("SPECTRUMPROBE " + JSON.stringify(win.report));
                Qt.quit();
            }
        }
    }
}
