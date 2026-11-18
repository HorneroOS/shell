import "modules/drawers" as Drawers
import "components/placement" as Placement
import "components/placement/Fillet.js" as Fillet
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.config

// Machined fillet harness (signal-visual-language §7.1): the real frame
// (modules/drawers/Border.qml), the real drawer backgrounds
// (modules/drawers/Backgrounds.qml) and the real popout frame
// (components/placement/SurfaceFrame.qml) around stub panels and a stub
// bar set that answers like modules/bar/BarSet.qml. Every scene is
// grabbed to FL_OUT/<scene>.png and reported on one FILLET line with the
// fillet radius each sheet drew. FL_FORCE0=1 renders every scene with
// fillet 0 (the golden flush look, also on trees without fillets).
ShellRoot {
    id: shell

    readonly property int sw: 1280
    readonly property int sh: 800
    readonly property string outDir: Quickshell.env("FL_OUT") || ""
    readonly property bool force0: Quickshell.env("FL_FORCE0") === "1"
    readonly property int barThickness: 40

    readonly property var scenes: [
        {name: "top-attached-f6", edges: {top: "attached"}, frame: true, fillet: 6},
        {name: "top-attached-f0", edges: {top: "attached"}, frame: true, fillet: 0},
        {name: "top-attached-f16", edges: {top: "attached"}, frame: true, fillet: 16},
        {name: "bottom-attached-f6", edges: {bottom: "attached"}, frame: true, fillet: 6},
        {name: "left-attached-f6", edges: {left: "attached"}, frame: true, fillet: 6},
        {name: "right-attached-f6", edges: {right: "attached"}, frame: true, fillet: 6},
        {name: "top-floating-f6", edges: {top: "floating"}, frame: true, fillet: 6},
        {name: "cockpit-clear-f6", edges: {top: "clear", bottom: "clear"}, frame: false, fillet: 6},
        {name: "noframe-top-attached-f6", edges: {top: "attached"}, frame: false, fillet: 6},
        {name: "top-attached-hc-f6", edges: {top: "attached"}, frame: true, fillet: 6, hc: true},
        {name: "top-attached-opening-f6", edges: {top: "attached"}, frame: true, fillet: 6, opening: true}
    ]
    property int index: -1
    property var scene: ({edges: {}, frame: true, fillet: 0})
    property var results: []

    function styleOn(edge: string): string {
        return shell.scene.edges[edge] ?? "";
    }

    function applyScene(s: var): void {
        shell.scene = s;
        // Trees without the setting (golden main) draw the flush look.
        if ("fillet" in Config.border)
            Config.border.fillet = shell.force0 ? 0 : s.fillet;
        Config.appearance.highContrast = !!s.hc;
    }

    function backgroundsReport(): var {
        const out = {};
        for (let i = 0; i < bgs.data.length; i++) {
            const p = bgs.data[i];
            if (p && "f" in p && "wrapper" in p)
                out[p.wrapper.objectName] = {f: p.f, c: p.c};
        }
        return out;
    }

    Window {
        id: win

        visible: true
        width: shell.sw
        height: shell.sh
        color: "#10131a"

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#2b3a55"
                    }
                    GradientStop {
                        position: 1
                        color: "#6b4a3a"
                    }
                }
            }

            // BarSet stand-in: one bar per configured edge.
            Item {
                id: bar

                readonly property bool frameVisible: shell.scene.frame
                readonly property int frameInset: frameVisible ? Config.border.thickness : 0
                readonly property bool floating: false
                readonly property string position: "top"

                function barOn(edge: string): Item {
                    return shell.styleOn(edge) !== "" ? bar : null;
                }
                function openOn(edge: string): bool {
                    const s = shell.styleOn(edge);
                    return s === "floating" || s === "clear";
                }
                function margin(edge: string): int {
                    return shell.styleOn(edge) !== "" ? shell.barThickness : frameInset;
                }
                function filletOn(edge: string): real {
                    return Fillet.radius(Config.border.fillet, openOn(edge), frameVisible, barOn(edge) !== null);
                }
                function filletRule(edge: string): real {
                    return Fillet.rule(frameVisible, barOn(edge) !== null, Config.appearance.highContrast, Config.border.edgeWidth);
                }

                readonly property int marginLeft: margin("left")
                readonly property int marginRight: margin("right")
                readonly property int marginTop: margin("top")
                readonly property int marginBottom: margin("bottom")
            }

            // Bar slabs where the frame does not back them (Bar.qml).
            Repeater {
                model: ["top", "bottom", "left", "right"]

                Rectangle {
                    id: slab

                    required property string modelData
                    readonly property string s: shell.styleOn(modelData)
                    readonly property bool vertical: modelData === "left" || modelData === "right"

                    visible: s === "floating" || (s === "attached" && !shell.scene.frame)
                    color: Signal.surface(Signal.layer(Signal.palette.base, 1), "bar")
                    radius: s === "floating" ? Appearance.rounding.small : 0
                    border.width: s === "floating" ? 1 : 0
                    border.color: Signal.palette.rule
                    readonly property int gap: s === "floating" ? 8 : 0
                    x: modelData === "right" ? shell.sw - shell.barThickness + (vertical ? gap : 0) : gap
                    y: modelData === "bottom" ? shell.sh - shell.barThickness + (vertical ? 0 : gap) : gap
                    width: vertical ? shell.barThickness - gap * 2 : shell.sw - gap * 2
                    height: vertical ? shell.sh - gap * 2 : shell.barThickness - gap * 2

                    Rectangle {
                        visible: slab.s === "attached"
                        color: Signal.palette.rule
                        x: slab.vertical ? (slab.modelData === "left" ? parent.width - 1 : 0) : 0
                        y: slab.vertical ? 0 : (slab.modelData === "top" ? parent.height - 1 : 0)
                        width: slab.vertical ? 1 : parent.width
                        height: slab.vertical ? parent.height : 1
                    }
                }
            }

            // The frame's fill is a MultiEffect mask, which the offscreen
            // software renderer does not draw: paint the same strip (base,
            // rounded cutout) underneath so renders read like the shell.
            Shape {
                anchors.fill: parent
                visible: bar.frameVisible

                ShapePath {
                    fillColor: Signal.palette.base
                    strokeWidth: -1
                    fillRule: ShapePath.OddEvenFill

                    PathRectangle {
                        width: shell.sw
                        height: shell.sh
                    }
                    PathRectangle {
                        x: bar.marginLeft
                        y: bar.marginTop
                        width: shell.sw - bar.marginLeft - bar.marginRight
                        height: shell.sh - bar.marginTop - bar.marginBottom
                        radius: Config.border.rounding
                    }
                }
            }

            Drawers.Border {
                bar: bar
                visible: bar.frameVisible
            }

            // Panels stand-in (modules/drawers/Panels.qml geometry).
            Item {
                id: panels

                readonly property real breathing: Appearance.spacing.large
                readonly property alias osd: osd
                readonly property alias notifications: notifications
                readonly property alias session: session
                readonly property alias launcher: launcher
                readonly property alias dashboard: dashboard
                readonly property alias utilities: utilities
                readonly property alias sidebar: sidebar

                anchors.fill: parent
                anchors.leftMargin: bar.marginLeft + (bar.openOn("left") ? breathing : 0)
                anchors.rightMargin: bar.marginRight + (bar.openOn("right") ? breathing : 0)
                anchors.topMargin: bar.marginTop + (bar.openOn("top") ? breathing : 0)
                anchors.bottomMargin: bar.marginBottom + (bar.openOn("bottom") ? breathing : 0)

                Item {
                    id: osd
                    objectName: "osd"
                    width: 56
                    height: 200
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                }
                Item {
                    id: notifications
                    objectName: "notifications"
                    width: 0
                    height: 0
                    anchors.top: parent.top
                    anchors.right: parent.right
                }
                Item {
                    id: session
                    objectName: "session"
                    width: 0
                    height: 0
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                }
                Item {
                    id: launcher
                    objectName: "launcher"
                    width: 460
                    height: 220
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                }
                Item {
                    id: dashboard
                    objectName: "dashboard"
                    width: 520
                    height: shell.scene.opening ? 9 : 180
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                }
                Item {
                    id: utilities
                    objectName: "utilities"
                    width: 300
                    height: 150
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                }
                Item {
                    id: sidebar
                    objectName: "sidebar"
                    width: 0
                    height: 0
                    anchors.right: parent.right
                }
            }

            Drawers.Backgrounds {
                id: bgs

                panels: panels
                bar: bar
            }

            // A bar popout against the first bar's inner edge (attached) or
            // 4 px off it (floating / clear), as the placement solver puts it.
            Placement.SurfaceFrame {
                id: popout

                readonly property string barEdge: Object.keys(shell.scene.edges)[0] ?? "top"
                readonly property string s: shell.styleOn(barEdge)
                readonly property int off: s === "attached" ? 0 : 4
                readonly property bool vertical: barEdge === "left" || barEdge === "right"

                edge: barEdge
                attached: s === "attached"
                notchStart: 40
                notchLength: 28
                width: vertical ? 200 : 220
                height: vertical ? 160 : 150
                x: barEdge === "left" ? bar.marginLeft + off : barEdge === "right" ? shell.sw - bar.marginRight - off - width : 110
                y: barEdge === "top" ? bar.marginTop + off : barEdge === "bottom" ? shell.sh - bar.marginBottom - off - height : 110
            }
        }
    }

    Timer {
        id: step

        interval: 700
        running: true
        repeat: false
        onTriggered: {
            if (shell.index >= 0) {
                const s = shell.scenes[shell.index];
                const r = {
                    name: s.name,
                    backgrounds: shell.backgroundsReport(),
                    popout: "fillet" in popout ? {fillet: popout.fillet, filletRule: popout.filletRule, attached: popout.attached, edge: popout.edge} : null
                };
                shell.results.push(r);
                const path = shell.outDir + "/" + s.name + ".png";
                stage.grabToImage(res => {
                    res.saveToFile(path);
                    shell.next();
                });
                return;
            }
            shell.next();
        }
    }

    function next(): void {
        shell.index++;
        if (shell.index >= shell.scenes.length) {
            console.log("FILLET " + JSON.stringify(shell.results));
            Qt.quit();
            return;
        }
        shell.applyScene(shell.scenes[shell.index]);
        if ("fillet" in popout) {
            popout.fillet = bar.filletOn(popout.barEdge);
            popout.filletRule = bar.filletRule(popout.barEdge);
        }
        step.restart();
    }
}
