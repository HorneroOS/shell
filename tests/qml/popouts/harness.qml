import "modules"
import "modules/companion"
import "modules/bar/popouts" as Popouts
import QtQuick
import QtQuick.Window
import Quickshell
import qs.services
import qs.config

// Real bar popout harness (shell#537, #512, #513, #582): the real popout
// surface (modules/bar/popouts/Wrapper.qml: AnchoredSurface, SurfaceFrame,
// Content and the native pages) opened from a trigger on one edge of a bar
// slab. Env: PO_EDGE (top|bottom|left|right), PO_STYLE (attached|floating),
// PO_NAME (popout id), PO_W/PO_H (logical screen), PO_OUT (png of the open
// state), PO_CLOSED (png after closing). Prints one POPO line.
ShellRoot {
    id: shell

    readonly property string edge: Quickshell.env("PO_EDGE") || "top"
    readonly property string style: Quickshell.env("PO_STYLE") || "attached"
    readonly property string popName: Quickshell.env("PO_NAME") || "audio"
    readonly property int sw: parseInt(Quickshell.env("PO_W") || "1280")
    readonly property int sh: parseInt(Quickshell.env("PO_H") || "800")
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int thickness: 40
    readonly property int gap: style === "floating" ? 8 : 0

    // Text that is elided, or that paints past the surface's own edge.
    function bad(item, out) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (!c)
                continue;
            if (c.visible && c.opacity > 0 && "truncated" in c && c.truncated)
                out.push({what: "truncated", text: String(c.text)});
            else if (c.visible && c.opacity > 0 && "contentWidth" in c && "text" in c && "elide" in c && String(c.text).length > 0) {
                const p = c.mapToItem(popouts, 0, 0);
                const right = p.x + Math.max(c.contentWidth, 0);
                const bottom = p.y + c.contentHeight;
                if (right > popouts.width + 0.5 || bottom > popouts.height + 0.5)
                    out.push({what: "outside", text: String(c.text), right: right, bottom: bottom, width: popouts.width, height: popouts.height});
            }
            bad(c, out);
        }
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
                color: "#10131a"
            }

            // Content behind the surface, so the frame is visible.
            Rectangle {
                x: shell.sw * 0.2
                y: shell.sh * 0.25
                width: shell.sw * 0.6
                height: shell.sh * 0.5
                color: "#1b1e26"
                border.color: "#3a3f4d"
            }

            Rectangle {
                id: slab

                color: "#161a22"
                x: shell.edge === "right" ? shell.sw - shell.thickness - shell.gap : shell.gap
                y: shell.edge === "bottom" ? shell.sh - shell.thickness - shell.gap : shell.gap
                width: shell.vertical ? shell.thickness : shell.sw - shell.gap * 2
                height: shell.vertical ? shell.sh - shell.gap * 2 : shell.thickness
            }

            Rectangle {
                id: trigger

                width: 28
                height: 28
                color: "#2a2f3b"
                x: shell.vertical ? slab.x + (slab.width - width) / 2 : shell.sw * 0.72
                y: shell.vertical ? shell.sh * 0.35 : slab.y + (slab.height - height) / 2
            }

            Popouts.Wrapper {
                id: popouts

                screen: Quickshell.screens[0]
                bounds: Qt.rect(0, 0, shell.sw, shell.sh)
                reserved: ({
                        top: shell.edge === "top" ? shell.thickness + shell.gap : 0,
                        bottom: shell.edge === "bottom" ? shell.thickness + shell.gap : 0,
                        left: shell.edge === "left" ? shell.thickness + shell.gap : 0,
                        right: shell.edge === "right" ? shell.thickness + shell.gap : 0
                    })
            }
        }
    }

    readonly property var spec: ({
            edge: shell.edge,
            style: shell.style,
            thickness: shell.thickness,
            margin: shell.gap,
            floating: shell.style === "floating",
            clear: false,
            item: slab
        })

    Timer {
        interval: 800
        running: true
        onTriggered: popouts.openFor(shell.popName, trigger, shell.spec, "click")
    }

    property var report: ({})

    Timer {
        interval: 2400
        running: true
        onTriggered: {
            const issues = [];
            shell.bad(popouts, issues);
            const f = popouts.frame;
            shell.report = {
                edge: shell.edge, style: shell.style, name: shell.popName, sw: shell.sw, sh: shell.sh,
                phase: popouts.phase,
                rect: [popouts.x, popouts.y, popouts.width, popouts.height],
                target: [popouts.target.x, popouts.target.y, popouts.target.width, popouts.target.height],
                trigger: [trigger.x, trigger.y, trigger.width, trigger.height],
                slab: [slab.x, slab.y, slab.width, slab.height],
                notch: [f.notchVisible, f.notchStart, f.notchLength],
                attached: popouts.placement.attached, side: popouts.placement.side,
                issues: issues
            };
            if (Quickshell.env("PO_OUT"))
                stage.grabToImage(function (r) { r.saveToFile(Quickshell.env("PO_OUT")); });
        }
    }

    Timer {
        interval: 2900
        running: true
        onTriggered: popouts.close()
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            const closed = {phase: popouts.phase, visible: popouts.visible, rect: [popouts.x, popouts.y, popouts.width, popouts.height], frameVisible: popouts.frame.visible, notchVisible: popouts.frame.notchVisible};
            if (Quickshell.env("PO_CLOSED"))
                stage.grabToImage(function (r) { r.saveToFile(Quickshell.env("PO_CLOSED")); });
            console.log("POPO " + JSON.stringify({open: shell.report, closed: closed}));
        }
    }

    Timer {
        interval: 4300
        running: true
        onTriggered: Qt.quit()
    }
}
