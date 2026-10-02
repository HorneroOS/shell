pragma Singleton

import qs.components
import qs.services
import qs.modules.companion
import qs.modules.controlcenter
import Quickshell
import QtQuick

Singleton {
    id: root

    // Tracked floating Settings windows. IPC `controlCenter close`
    // destroys all of them; `create` reuses the first one so repeated
    // opens never stack duplicate windows.
    property var windows: []

    // Companion yield: a Settings window is a focused configuration
    // surface, and the Overlay-layer companion paints above every
    // toplevel (docs/COMPANION.md z-order policy). Report open state
    // so the companion hides while Settings is up and returns after.
    function syncCompanion(): void {
        CompanionStore.controlCenterOpen = windows.length > 0;
    }

    function create(parent: Item, props: var): void {
        prune();
        if (windows.length > 0) {
            const existing = windows[0];
            const pane = props?.pane?.toString() ?? "";
            if (pane !== "" && PaneRegistry.getById(pane))
                existing.active = pane;
            root.syncCompanion();
            return;
        }
        const win = controlCenter.createObject(parent ?? dummy, props);
        if (win)
            windows.push(win);
        root.syncCompanion();
    }

    function closeAll(): void {
        const open = windows;
        windows = [];
        root.syncCompanion();
        for (let i = 0; i < open.length; ++i) {
            // Tracked refs can outlive their window across engine reloads
            // or teardown; never let a dead ref break the close path.
            try {
                if (open[i])
                    open[i].destroy();
            } catch (e) {
                console.warn(`[WindowFactory] dropping dead settings window: ${e}`);
            }
        }
    }

    function forget(win: Item): void {
        windows = windows.filter(w => w && w !== win);
        root.syncCompanion();
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

            // QWindow defaults to hidden. `onVisibleChanged` below treats
            // a hidden window as a user close, so dynamic creation must
            // explicitly show the new Settings surface before that handler
            // can destroy it.
            visible: true

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
                onActivated: {
                    if (cc.searchOpen) {
                        if (cc.session.searchQuery.length > 0)
                            cc.session.searchQuery = "";
                        else
                            cc.searchOpen = false;
                    } else {
                        win.destroy();
                    }
                }
            }

            Shortcut {
                sequences: ["Ctrl+,"]
                context: Qt.WindowShortcut
                onActivated: {
                    cc.searchOpen = true;
                    cc.session.searchSelection = 0;
                }
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
