import "modules"
import "modules/companion"
import "modules/plugins"
import "modules/bar/components"
import QtQuick
import QtQuick.Window
import Quickshell
import qs.services

// Plugin bar overflow harness (shell#531): the real Quick actions island and
// Extensions island over the real Plugins service, fed by generated fixture
// plugins that all join the `actions` section with wide labels. Prints one
// POVF line with the geometry of every plugin indicator that is on screen.
ShellRoot {
    id: shell

    readonly property int sw: parseInt(Quickshell.env("OV_W"))
    readonly property int sh: 120

    PluginHost {}

    Window {
        id: win

        visible: true
        width: shell.sw
        height: shell.sh
        color: "#10131a"

        Rectangle {
            anchors.fill: parent
            color: "#10131a"
        }

        Row {
            id: bar

            spacing: 24
            x: 40
            y: 20

            QuickActions {
                id: actions

                vertical: false
                screenName: Quickshell.screens[0].name
            }

            ExtensionsIsland {
                id: island

                screen: Quickshell.screens[0]
                vertical: false
            }
        }
    }

    function walk(item, out) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (c && "measuredMain" in c)
                out.push(c);
            walk(c, out);
        }
    }

    Timer {
        interval: 8500
        running: Quickshell.env("OV_OUT") !== null && Quickshell.env("OV_OUT") !== ""
        onTriggered: win.contentItem.grabToImage(function (r) {
            r.saveToFile(Quickshell.env("OV_OUT"));
        })
    }

    Timer {
        interval: 9000
        running: true
        onTriggered: {
            const loaders = [];
            shell.walk(bar, loaders);
            const rects = [];
            for (const l of loaders) {
                if (!l.visible || l.width <= 0 || l.height <= 0)
                    continue;
                const p = l.mapToItem(null, 0, 0);
                // The host that owns the loader: actions row or island.
                let host = "other";
                let it = l;
                while (it) {
                    if (it === actions)
                        host = "actions";
                    else if (it === island)
                        host = "island";
                    it = it.parent;
                }
                rects.push({id: l.modelData.id, host: host, x: p.x, y: p.y, w: l.width, h: l.height, active: l.active});
            }
            console.log("POVF " + JSON.stringify({
                sw: shell.sw,
                actionsRect: [actions.mapToItem(null, 0, 0).x, actions.width],
                islandRect: [island.mapToItem(null, 0, 0).x, island.width, island.visible],
                overflow: Plugins.barOverflow,
                sinks: Plugins.overflowSinks,
                states: Plugins.entries.map(e => e.id + ":" + e.state),
                details: Plugins.entries.map(e => e.detail),
                rects: rects
            }));
            Qt.quit();
        }
    }
}
