import "modules/instruments" as Instruments
import QtQuick
import QtQuick.Window
import Quickshell
import qs.components
import qs.services
import qs.config

// Slider handle readout harness (signal-visual-language §6.2): real
// SegmentSliders as the OSD (vertical, 20 segments, value echo on) and
// the dashboard seek bar (horizontal, timecode readout) use them. A
// scripted timeline grabs SR_OUT/<step>.png at rest, while reading out,
// after the hold and with motion off, and prints one SLIDER line.
ShellRoot {
    id: shell

    readonly property string outDir: Quickshell.env("SR_OUT") || ""
    property var probes: ({})

    function capOf(slider: Item): Item {
        for (let i = 0; i < slider.children.length; i++) {
            const c = slider.children[i];
            if (c && "capAlong" in c)
                return c;
        }
        return null;
    }

    function textsIn(item: Item): var {
        const out = [];
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (c && "text" in c)
                out.push({text: String(c.text), opacity: c.opacity, family: String(c.font?.family ?? "")});
        }
        return out;
    }

    function meterOf(slider: Item): Item {
        for (let i = 0; i < slider.children.length; i++) {
            const c = slider.children[i];
            if (c && "lit" in c)
                return c;
        }
        return null;
    }

    function look(slider: Item): var {
        const cap = shell.capOf(slider);
        const m = shell.meterOf(slider);
        return {h: slider.height, w: slider.width, meter: m ? {y: m.y, h: m.height, w: m.width, lit: m.lit} : null, reading: slider.reading, valueText: slider.valueText, a11yDescription: String(slider.Accessible.description), cap: cap ? {x: cap.x, y: cap.y, w: cap.width, h: cap.height, visible: cap.visible, colour: String(cap.color), texts: shell.textsIn(cap)} : null};
    }

    function probe(name: string): void {
        shell.probes[name] = {vol: shell.look(vol), seek: shell.look(seek)};
    }

    function shot(name: string): void {
        if (shell.outDir)
            stage.grabToImage(r => r.saveToFile(shell.outDir + "/" + name + ".png"));
    }

    Window {
        visible: true
        width: 360
        height: 260
        color: "#10131a"

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Signal.palette.panel
            }

            Instruments.SegmentSlider {
                id: vol

                x: 40
                y: 24
                width: 12
                height: 98
                count: 20
                to: 1.5
                threshold: 1 / 1.5
                value: 0.72
                accessibleName: "Volume"
                glyph: "volume"
                readoutOnChange: true
            }

            Instruments.SegmentSlider {
                id: seek

                x: 100
                y: 110
                width: 230
                height: 12
                vertical: false
                count: 46
                threshold: 2
                value: 0.4
                accessibleName: "Playback position"
                valueText: "1:23"
            }
        }
    }

    // Grabs are asynchronous: every mutation waits for the next step.
    readonly property var steps: [
        [1200, () => {
            shell.probe("rest");
            shell.shot("01-rest-glyphs");
        }],
        [200, () => {
            vol.value = 0.85;      // a volume key or a wheel on the OSD
            seek.nudge();          // a wheel over the seek bar
        }],
        [300, () => {
            shell.probe("reading");
            shell.shot("02-reading-values");
        }],
        [1100, () => {
            shell.probe("afterHold");
            shell.shot("03-back-to-glyphs");
        }],
        [200, () => {
            Config.appearance.reducedMotion = true;
            vol.value = 1.2;
        }],
        [30, () => {
            shell.probe("offInstant");
            shell.shot("04-motion-off-instant");
        }],
        [200, () => {
            Config.appearance.reducedMotion = false;
            Config.appearance.sliders.readout = false;
            vol.value = 0.5;
        }],
        [300, () => {
            shell.probe("readoutDisabled");
            shell.shot("05-readout-disabled");
        }],
        [200, () => {
            console.log("SLIDER " + JSON.stringify(shell.probes));
            Qt.quit();
        }]
    ]
    property int stepIndex: 0

    Timer {
        running: true
        interval: shell.steps[0][0]
        onTriggered: {
            shell.steps[shell.stepIndex][1]();
            shell.stepIndex++;
            if (shell.stepIndex < shell.steps.length) {
                interval = shell.steps[shell.stepIndex][0];
                restart();
            }
        }
    }
}
