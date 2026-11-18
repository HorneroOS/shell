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
        Timer { interval: 6000; running: true; onTriggered: stage.grabToImage(function(r) { r.saveToFile(root.outPath); Qt.quit() }) }
    }
}
