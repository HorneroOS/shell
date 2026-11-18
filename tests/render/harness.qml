import QtQuick
import QtQuick.Window
import Quickshell
import qs.services
import qs.config
import qs.modules.bar

ShellRoot {
    id: root
    readonly property int sw: parseInt(Quickshell.env("HW"))
    readonly property int sh: parseInt(Quickshell.env("HH"))
    readonly property string outPath: Quickshell.env("HOUT")
    readonly property var specs: Config.bar.barsFor("")
    // Needle travel frames (tests/test_workspace_needle.py): switch to
    // workspace WSTO after the strip settles, then grab HFRAMECOUNT frames
    // HFRAMEMS apart into HFRAMES/, logging the live geometry per frame.
    readonly property int wsTo: parseInt(Quickshell.env("WSTO") || "0")
    readonly property string frameDir: Quickshell.env("HFRAMES") || ""
    readonly property int frameMs: parseInt(Quickshell.env("HFRAMEMS") || "100")
    readonly property int frameCount: parseInt(Quickshell.env("HFRAMECOUNT") || "0")
    property real t0: 0
    property int frame: 0

    function geo(): var {
        // Strips register on creation; Loader churn destroys some (their
        // refs go null), so take the live one with a cell layout.
        const live = Hypr.harnessStrips.filter(x => x && x.harnessCells && x.width > 0);
        const s = live.length ? live[live.length - 1] : null;
        const p = s?.harnessPlate ?? null;
        const cs = [];
        const rep = s?.harnessCells ?? null;
        for (let i = 0; rep && i < rep.count; i++) {
            const c = rep.itemAt(i);
            const r = c.mapToItem(stage, 0, 0);
            cs.push({ws: c.ws, visible: c.visible, x: r.x, y: r.y, w: c.width, h: c.height, nx: r.x + c.numeralX, ny: r.y + c.numeralY, nw: c.numeralW, nh: c.numeralH, gap: c.gapBefore});
        }
        const out = {t: Date.now() - root.t0, cells: cs, vertical: s?.vertical ?? false, edge: s?.edge ?? "", receded: s?.receded ?? false, ink: String(s?.tone.ink ?? ""), inkMuted: String(s?.tone.inkMuted ?? "")};
        if (p) {
            const pr = p.mapToItem(stage, 0, 0);
            out.plate = {x: pr.x, y: pr.y, w: p.width, h: p.height, len: p.length, rest: p.restLength, start: p.startEdge, end: p.endEdge, needle: p.needle};
        }
        return out;
    }

    Window {
        id: win
        visible: true
        width: root.sw
        height: root.sh
        color: "#10131a"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#2b3a55" }
                    GradientStop { position: 1; color: "#6b4a3a" }
                }
            }
            Rectangle {
                x: root.sw * 0.25; y: root.sh * 0.2; width: root.sw * 0.5; height: root.sh * 0.55
                color: "#1b1e26"; radius: 4; border.color: "#3a3f4d"
                Text { anchors.centerIn: parent; color: "#9aa3b5"; text: "window"; font.pixelSize: 14 }
            }
            // Frame ring + strip slabs, as the drawers frame paints them (approximation)
            Item {
                anchors.fill: parent
                Repeater {
                    model: root.specs
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool vert: modelData.edge === "left" || modelData.edge === "right"
                        visible: Config.border.frameEnabled && modelData.style === "attached"
                        color: Signal.surface(Signal.layer(Signal.palette.base, 1), "bar")
                        readonly property int th: Density.thickness(modelData.thickness)
                        x: modelData.edge === "right" ? root.sw - th : 0
                        y: modelData.edge === "bottom" ? root.sh - th : 0
                        width: vert ? th : root.sw
                        height: vert ? root.sh : th
                    }
                }
            }
            Repeater {
                model: root.specs
                delegate: Item {
                    id: d
                    required property var modelData
                    readonly property bool vert: modelData.edge === "left" || modelData.edge === "right"
                    readonly property int th: Density.thickness(modelData.thickness) + (modelData.style === "attached" ? 0 : modelData.margin)
                    x: modelData.edge === "right" ? root.sw - th : 0
                    y: modelData.edge === "bottom" ? root.sh - th : 0
                    width: vert ? th : root.sw
                    height: vert ? root.sh : th
                    Bar {
                        anchors.fill: parent
                        screen: Quickshell.screens[0]
                        visibilities: null
                        popouts: null
                        spec: d.modelData
                    }
                }
            }
        }
        Timer {
            interval: 5000
            running: root.wsTo > 0
            onTriggered: {
                console.log("NEEDLEREST " + JSON.stringify(root.geo()));
                root.t0 = Date.now();
                Hypr.harnessWs = root.wsTo;
                frames.start();
            }
        }
        Timer {
            id: frames
            interval: root.frameMs
            repeat: true
            onTriggered: {
                const i = root.frame++;
                if (root.frame >= root.frameCount)
                    stop();
                const at = root.geo();
                stage.grabToImage(function(r) {
                    r.saveToFile(root.frameDir + "/frame-" + String(i).padStart(2, "0") + ".png");
                    console.log("NEEDLEFRAME " + JSON.stringify({i: i, at: at, done: root.geo()}));
                });
            }
        }
        Timer { interval: root.wsTo > 0 ? 5000 + root.frameMs * root.frameCount + 2500 : 6000; running: true; onTriggered: stage.grabToImage(function(r) { r.saveToFile(root.outPath); Qt.quit() }) }
    }
}
