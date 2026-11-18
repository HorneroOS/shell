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
                id: barRepeater
                model: root.specs
                delegate: Item {
                    id: d
                    property alias bar: theBar
                    required property var modelData
                    readonly property bool vert: modelData.edge === "left" || modelData.edge === "right"
                    readonly property int th: Density.thickness(modelData.thickness) + (modelData.style === "attached" ? 0 : modelData.margin)
                    x: modelData.edge === "right" ? root.sw - th : 0
                    y: modelData.edge === "bottom" ? root.sh - th : 0
                    width: vert ? th : root.sw
                    height: vert ? root.sh : th
                    Bar {
                        id: theBar
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
            interval: 5500
            running: true
            onTriggered: {
                const rects = [];
                const issues = [];
                const bars = [];
                function collect(it, out) { for (let i = 0; i < it.children.length; i++) out.push(it.children[i]); }
                for (let b = 0; b < barRepeater.count; b++) {
                    const hostItem = barRepeater.itemAt(b);
                    const bar = hostItem ? hostItem.bar : null;
                    if (!bar) continue;
                    const rs = [];
                    for (const l of bar.entryLoaders) {
                        if (!l || !l.visible || !l.item || l.width <= 0 || l.height <= 0) continue;
                        const p = l.mapToItem(stage, 0, 0);
                        const q = l.item.mapToItem(stage, 0, 0);
                        rs.push({id: l.id, x: p.x, y: p.y, w: l.width, h: l.height, iw: l.item.width, ih: l.item.height, ix: q.x, iy: q.y});
                    }
                    for (let i = 0; i < rs.length; i++) {
                        const a = rs[i];
                        if (a.x < -0.5 || a.y < -0.5 || a.x + a.w > root.sw + 0.5 || a.y + a.h > root.sh + 0.5)
                            issues.push({bar: b, kind: "offscreen", a: a.id});
                        for (let j = i + 1; j < rs.length; j++) {
                            const c = rs[j];
                            const ox = Math.min(a.x + a.w, c.x + c.w) - Math.max(a.x, c.x);
                            const oy = Math.min(a.y + a.h, c.y + c.h) - Math.max(a.y, c.y);
                            if (ox > 1 && oy > 1)
                                issues.push({bar: b, kind: "overlap", a: a.id, b: c.id, ox: Math.round(ox), oy: Math.round(oy)});
                        }
                        // An item wider/taller than its loader paints outside its slot.
                        const vert = hostItem.vert;
                        const over = vert ? a.iw - a.w : a.iw - a.w;
                        if (a.iw - a.w > 1 || a.ih - a.h > 1)
                            issues.push({bar: b, kind: "overflow", a: a.id, iw: Math.round(a.iw), w: Math.round(a.w), ih: Math.round(a.ih), h: Math.round(a.h)});
                    }
                    bars.push({edge: bar.edge, style: bar.style, n: rs.length, rects: rs.map(r => r.id + "@" + Math.round(r.x) + "," + Math.round(r.y) + " " + Math.round(r.w) + "x" + Math.round(r.h))});
                }
                console.log("QAM " + JSON.stringify({sw: root.sw, sh: root.sh, issues: issues, bars: bars}));
            }
        }
        Timer { interval: 6000; running: true; onTriggered: stage.grabToImage(function(r) { r.saveToFile(root.outPath); Qt.quit() }) }
    }
}
