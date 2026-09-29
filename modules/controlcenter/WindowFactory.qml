pragma Singleton

import qs.components
import qs.services
import qs.modules.controlcenter
import Quickshell
import QtQuick

Singleton {
    id: root

    // Tracked floating Settings windows. IPC `controlCenter close`
    // destroys all of them; `create` reuses the first one so repeated
    // opens never stack duplicate windows.
    property var windows: []

    function create(parent: Item, props: var): void {
        prune();
        if (windows.length > 0) {
            const existing = windows[0];
            const pane = props?.pane?.toString() ?? "";
            if (pane !== "" && PaneRegistry.getById(pane))
                existing.active = pane;
            return;
        }
        const win = controlCenter.createObject(parent ?? dummy, props);
        if (win)
            windows.push(win);
    }

    function closeAll(): void {
        const open = windows;
        windows = [];
        for (let i = 0; i < open.length; ++i) {
            if (open[i])
                open[i].destroy();
        }
    }

    function forget(win: Item): void {
        windows = windows.filter(w => w && w !== win);
    }

    function prune(): void {
        windows = windows.filter(w => w);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: controlCenter

        FloatingWindow {
            id: win

            property alias active: cc.active
            property alias navExpanded: cc.navExpanded
            // Deep-link target validated by the caller against
            // PaneRegistry; applied once the content exists.
            property string pane: ""

            color: Colours.tPalette.m3surface

            Component.onCompleted: {
                if (win.pane !== "" && PaneRegistry.getById(win.pane))
                    cc.active = win.pane;
            }

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            Component.onDestruction: root.forget(win)

            // Keyboard round-trip: Escape dismisses Settings, matching
            // the Welcome window precedent.
            Shortcut {
                sequences: ["Escape"]
                context: Qt.WindowShortcut
                onActivated: win.destroy()
            }

            implicitWidth: cc.implicitWidth
            implicitHeight: cc.implicitHeight

            minimumSize.width: implicitWidth
            minimumSize.height: implicitHeight
            maximumSize.width: implicitWidth
            maximumSize.height: implicitHeight

            title: qsTr("Hornero Settings - %1").arg(cc.active.slice(0, 1).toUpperCase() + cc.active.slice(1))

            ControlCenter {
                id: cc

                anchors.fill: parent
                screen: win.screen
                floating: true

                function close(): void {
                    win.destroy();
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
