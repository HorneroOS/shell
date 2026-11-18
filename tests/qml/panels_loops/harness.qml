import "modules/drawers" as Drawers
import "components/placement/Fillet.js" as Fillet
import QtQuick
import QtQuick.Window
import Quickshell
import qs.config

// Binding-loop harness: the real drawer panels (modules/drawers/Panels.qml,
// with the real bar popout surface) on a logical screen next to a stand-in
// bar set that answers like modules/bar/BarSet.qml, attached on PL_EDGE.
// Opens a bar popout once, then quits; the test fails on any binding-loop
// warning in the log.
ShellRoot {
    id: shell

    readonly property string edge: Quickshell.env("PL_EDGE") || "top"

    PersistentProperties {
        id: vis

        property bool bar
        property bool osd
        property bool session
        property bool launcher
        property bool dashboard
        property bool utilities
        property bool sidebar
        property bool layoutPicker
        reloadableId: "plHarnessVis"
    }

    Window {
        visible: true
        width: 1280
        height: 800
        color: "#10131a"

        Item {
            id: bar

            readonly property bool frameVisible: true
            readonly property int frameInset: Config.border.thickness
            readonly property bool floating: false
            readonly property string position: shell.edge

            function barOn(e: string): Item {
                return e === shell.edge ? bar : null;
            }
            function openOn(e: string): bool {
                return false;
            }
            function margin(e: string): int {
                return e === shell.edge ? 40 : frameInset;
            }
            function filletOn(e: string): real {
                return Fillet.radius(Config.border.fillet, openOn(e), frameVisible, barOn(e) !== null);
            }
            function filletRule(e: string): real {
                return Fillet.rule(frameVisible, barOn(e) !== null, Config.appearance.highContrast, Config.border.edgeWidth);
            }

            readonly property int marginLeft: margin("left")
            readonly property int marginRight: margin("right")
            readonly property int marginTop: margin("top")
            readonly property int marginBottom: margin("bottom")
        }

        Rectangle {
            id: trigger

            x: shell.edge === "right" ? 1280 - 34 : shell.edge === "left" ? 6 : 900
            y: shell.edge === "bottom" ? 800 - 34 : shell.edge === "top" ? 6 : 300
            width: 28
            height: 28
        }

        Drawers.Panels {
            id: panels

            screen: Quickshell.screens[0]
            visibilities: vis
            bar: bar
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: panels.popouts.openFor("audio", trigger, {edge: shell.edge, style: "attached", thickness: 40, margin: 0, floating: false, clear: false}, "click")
    }

    Timer {
        interval: 3500
        running: true
        onTriggered: {
            console.log("PANELS-DONE " + JSON.stringify({edge: panels.popouts.edge, fillet: panels.popouts.fillet, attached: panels.popouts.placement.attached}));
            Qt.quit();
        }
    }
}
