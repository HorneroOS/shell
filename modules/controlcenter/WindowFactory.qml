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
    property int nextWindowToken: 0
    property var pendingFocusWindow: null
    property int focusAttemptsRemaining: 0

    function focusSettingsWindow(win: var): void {
        if (!win || !win.visible)
            return;
        root.pendingFocusWindow = win;
        root.focusAttemptsRemaining = 10;
        focusTimer.restart();
        Qt.callLater(() => root.tryFocusSettingsWindow());
    }

    function tryFocusSettingsWindow(): void {
        const win = root.pendingFocusWindow;
        if (!win || !win.visible) {
            focusTimer.stop();
            root.pendingFocusWindow = null;
            return;
        }
        if (Compositor.activeWindowAppId === "org.quickshell" && Compositor.activeWindowTitle.startsWith("Hornero Settings - ")) {
            focusTimer.stop();
            root.pendingFocusWindow = null;
            return;
        }

        // Compositor IPC can report the new toplevel a moment after QML has
        // created it. Keep retrying briefly so a fast open cannot leave
        // Settings behind the current application.
        Compositor.focusWindowByAppIdAndTitlePrefix("org.quickshell", "Hornero Settings - ");
        root.focusAttemptsRemaining -= 1;
        if (root.focusAttemptsRemaining <= 0) {
            focusTimer.stop();
            root.pendingFocusWindow = null;
            console.warn("[WindowFactory] Settings window did not become focused after retries");
        }
    }

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
            root.focusSettingsWindow(existing);
            root.syncCompanion();
            return;
        }
        const win = controlCenter.createObject(parent ?? dummy, props);
        if (win) {
            root.nextWindowToken += 1;
            win.registryToken = root.nextWindowToken;
            windows.push(win);
            root.focusSettingsWindow(win);
        }
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

    function forget(win: var): void {
        let token = -1;
        try {
            if (win)
                token = win.registryToken;
        } catch (e) {
            // Destruction callbacks can arrive after the QWindow wrapper died.
        }
        windows = windows.filter(w => {
            try {
                return w && w.registryToken !== token;
            } catch (e) {
                return false;
            }
        });
        root.syncCompanion();
    }

    function closeWindow(win: var): void {
        // Drop the reference before requesting deferred QObject destruction.
        // A second open can arrive before Component.onDestruction runs.
        if (root.pendingFocusWindow === win) {
            focusTimer.stop();
            root.pendingFocusWindow = null;
        }
        root.forget(win);
        try {
            if (win)
                win.destroy();
        } catch (e) {
            console.warn(`[WindowFactory] dropping dead Settings window: ${e}`);
        }
    }

    function prune(): void {
        windows = windows.filter(w => {
            try {
                return w && w.visible;
            } catch (e) {
                return false;
            }
        });
    }

    Timer {
        id: focusTimer

        interval: 120
        repeat: true
        onTriggered: root.tryFocusSettingsWindow()
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
            property int registryToken: 0
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
                    root.closeWindow(win);
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
                        root.closeWindow(win);
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

            // Preserve the screen-proportional opening size while allowing
            // users to resize Settings. The 16:9 implicit dimensions should
            // be a starting point, not a compositor-enforced maximum.
            minimumSize.width: Math.min(1150, screen.width * 0.9)
            minimumSize.height: Math.min(650, screen.height * 0.9)

            title: qsTr("Hornero Settings - %1").arg(cc.session.activeTitle)

            ControlCenter {
                id: cc

                anchors.fill: parent
                screen: win.screen
                floating: true

                function close(): void {
                    root.closeWindow(win);
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
