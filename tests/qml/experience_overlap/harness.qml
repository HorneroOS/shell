import QtQuick
import QtQuick.Window
import Quickshell
import qs.services
import qs.config
import qs.modules.controlcenter

// Offscreen render of the real Control Center pane stack (Panes.qml) on
// the Experience pane with a customised config, so the neighbouring
// Customisation pane is warm and tall. Driven by
// tests/test_experience_header_overlap.py (shell#650).
//
// Scene A: the stack as shipped. Scene B: the Customisation pane hidden.
// The Experience header strip must be pixel-identical in A and B; if a
// neighbouring pane paints over it (the bug), A differs from B.
// HOUT_A / HOUT_B are PNG paths; the result is one HRESULT line.
ShellRoot {
    id: root

    property var out: ({})
    property int tick: 0
    property var customisationItem: null

    function emit(): void {
        console.log("HRESULT " + JSON.stringify(root.out));
        Qt.quit();
    }

    function findByType(item: var, name: string): var {
        if (item.toString().indexOf(name) === 0)
            return item;
        const kids = item.children;
        for (let i = 0; i < kids.length; i++) {
            const hit = root.findByType(kids[i], name);
            if (hit)
                return hit;
        }
        return null;
    }

    Window {
        id: win

        visible: true
        width: 1100
        height: 760
        color: Signal.palette.ground

        Item {
            id: host

            anchors.fill: parent
        }

        Session {
            id: session

            root: host
        }

        Panes {
            id: panes

            anchors.fill: parent
            session: session
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            root.tick++;
            if (root.tick === 2)
                session.navigateTo("experience", "");
            if (root.tick === 14) {
                root.customisationItem = root.findByType(panes, "CustomisationPane");
                root.out.customisationLoaded = root.customisationItem !== null;
                root.out.customisedRows = root.customisationItem ? root.customisationItem.items.length : -1;
                root.out.experienceLoaded = root.findByType(panes, "ExperiencePane") !== null;
                root.out.activePane = session.active;
                const ex = root.findByType(panes, "ExperiencePane");
                root.out.exGeom = ex ? [ex.x, ex.y, ex.width, ex.height, ex.visible, ex.opacity, ex.mapToItem(panes, 0, 0).y] : null;
                root.out.ground = String(Signal.palette.ground);
                root.out.panesGeom = [panes.width, panes.height, panes.visible, session.activeIndex];
                if (ex) ex.grabToImage(i => { i.saveToFile(Quickshell.env("HOUT_A") + ".ex.png"); });
                win.contentItem.grabToImage(img => {
                    root.out.savedA = img.saveToFile(Quickshell.env("HOUT_A"));
                    if (root.customisationItem)
                        root.customisationItem.visible = false;
                    Qt.callLater(root.grabB);
                });
            }
        }
    }

    function grabB(): void {
        win.contentItem.grabToImage(img => {
            root.out.savedB = img.saveToFile(Quickshell.env("HOUT_B"));
            root.emit();
        });
    }
}
