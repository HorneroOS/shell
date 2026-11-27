pragma ComponentBehavior: Bound

import qs.components.placement
import qs.components.motion
import qs.services
import qs.config
import qs.modules.windowinfo
import qs.modules.controlcenter
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// The bar popout surface of one screen: a single AnchoredSurface shared
// by every bar of the screen (docs/INTERACTION.md). Bars ask for a popout
// with openFor(); the surface places itself with the shared solver from
// the owning bar, grows from the trigger notch, morphs between adjacent
// triggers and closes with the hover grace. Detached windows (window info,
// Control Center) are centred pages of the same surface.
AnchoredSurface {
    id: root

    required property ShellScreen screen

    // ---- Public state (bars, drawers, tray menus, launcher) ----

    property string currentName
    property Item currentAnchor
    property bool hasCurrent
    // Explicit keyboard/click activation may hold the keyboard; hover
    // opens never do (RFC §4 rule 5).
    property bool keyboardIntent: false

    // Owning bar of the current popout (Bar.surfaceOwner): edge, style,
    // backdrop and its slab item for the live anchor line.
    property var ownerSpec: null
    readonly property string ownerEdge: ownerSpec?.edge ?? Config.bar.positionFor(screen.name)
    readonly property string ownerStyle: ownerSpec?.style ?? Config.bar.styleFor(screen.name)
    readonly property string ownerBackdrop: ownerSpec?.clear ? "clear" : "solid"
    readonly property bool barVertical: ownerEdge === "left" || ownerEdge === "right"
    readonly property string barPosition: ownerEdge

    readonly property Item current: popoutContent.current
    // Final (not animating) size and trigger centre along the bar.
    readonly property real nonAnimWidth: target.width
    readonly property real nonAnimHeight: target.height
    readonly property real currentCenter: barVertical ? anchorRect.y + anchorRect.height / 2 : anchorRect.x + anchorRect.width / 2

    property string detachedMode
    property string queuedMode
    readonly property bool isDetached: detachedMode.length > 0

    // ---- Requests ----

    // Open (or switch to) popout `name` anchored on `anchor`, owned by the
    // bar described by `owner`. Hover requests honour the 120 ms intent
    // delay when nothing is open; while a popout is open they switch at
    // once and the frame morphs (visual language §11.1 rule 5).
    function openFor(name: string, anchor: Item, owner: var, how: string): void {
        if (!anchor)
            return;
        closeGrace.stop();
        const hover = how === "hover";
        if (hover && !root.hasCurrent) {
            if (pending.name === name && pending.anchor === anchor && openIntent.running)
                return;
            pending.name = name;
            pending.anchor = anchor;
            pending.owner = owner;
            openIntent.restart();
            return;
        }
        openIntent.stop();
        pending.clear();
        root._apply(name, anchor, owner, how);
    }

    function _apply(name: string, anchor: Item, owner: var, how: string): void {
        root.ownerSpec = owner;
        root.intent = root.hasCurrent ? root.intent : how;
        root.keyboardIntent = how !== "hover";
        root.currentName = name;
        root.currentAnchor = anchor;
        root.hasCurrent = true;
    }

    // Pointer left the bar and the surface: close after the grace period
    // unless it comes back (RFC §4 rule 6). Explicitly opened surfaces
    // ignore hover and close on Escape, outside click or their trigger.
    function hoverLeave(): void {
        openIntent.stop();
        pending.clear();
        if (!root.hasCurrent || root.keyboardIntent || root.isDetached)
            return;
        if (!closeGrace.running)
            closeGrace.restart();
    }

    // Pointer is over the surface or its trigger: keep it open.
    function holdOpen(): void {
        closeGrace.stop();
    }

    function detach(mode: string): void {
        if (mode === "winfo" && !Compositor.supports("nativeWindowThumbnails"))
            return;
        if (mode === "winfo") {
            detachedMode = mode;
        } else {
            queuedMode = mode;
            detachedMode = "any";
        }
        focus = true;
    }

    function close(): void {
        openIntent.stop();
        closeGrace.stop();
        pending.clear();
        hasCurrent = false;
        detachedMode = "";
    }

    // ---- Surface wiring ----

    anchorItem: isDetached ? null : currentAnchor
    centred: isDetached
    owner: isDetached ? null : ownerSpec
    ownerItem: isDetached ? null : (ownerSpec?.item ?? null)
    open: hasCurrent || isDetached
    key: isDetached ? `detached:${detachedMode}` : currentName
    keyboardFocused: (keyboardIntent && hasCurrent) || isDetached
    preferredWidth: isDetached ? (detachedMode === "winfo" ? winfoPage : sheetPage).preferredWidth : popoutContent.preferredWidth
    preferredHeight: isDetached ? (detachedMode === "winfo" ? winfoPage : sheetPage).preferredHeight : popoutContent.preferredHeight
    devicePixelRatio: screen?.devicePixelRatio ?? 1
    // Detached windows are full sheets (radius large, visual language §7.1).
    radius: isDetached ? Appearance.rounding.large : Appearance.rounding.small
    notch: !isDetached

    onHasCurrentChanged: {
        if (!hasCurrent) {
            keyboardIntent = false;
            closeGrace.stop();
        }
    }
    onClosed: {
        if (!hasCurrent && !isDetached) {
            currentName = "";
            currentAnchor = null;
            intent = "click";
        }
    }

    focus: hasCurrent || isDetached
    Keys.onEscapePressed: event => {
        // Inner transient state first (escape cascade): the password
        // dialog steps back to the network list.
        if (currentName === "wirelesspassword") {
            const page = popoutContent.pageFor("wirelesspassword");
            if (page?.item) {
                page.item.closeDialog();
                return;
            }
        }
        const trigger = currentAnchor;
        close();
        // Keyboard-opened surfaces return focus to their trigger.
        if (trigger && trigger.activeFocusOnTab)
            trigger.forceActiveFocus();
    }

    Keys.onPressed: event => {
        // The password page handles its own keys.
        if (currentName === "wirelesspassword")
            event.accepted = false;
    }

    QtObject {
        id: pending

        property string name: ""
        property Item anchor: null
        property var owner: null

        function clear(): void {
            name = "";
            anchor = null;
            owner = null;
        }
    }

    // RFC §4 rule 6: 120 ms hover intent before a popout opens.
    Timer {
        id: openIntent

        interval: Choreography.hoverOpenDelay
        onTriggered: {
            if (pending.anchor)
                root._apply(pending.name, pending.anchor, pending.owner, "hover");
            pending.clear();
        }
    }

    // ...and a 240 ms close grace bridged across the trigger/surface gap.
    Timer {
        id: closeGrace

        interval: Choreography.hoverCloseGrace
        onTriggered: {
            if (!root.keyboardIntent)
                root.hasCurrent = false;
        }
    }

    HyprlandFocusGrab {
        active: Compositor.isHyprland && root.isDetached
        windows: [QsWindow.window]
        onCleared: root.close()
    }

    Binding {
        when: root.isDetached

        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    Binding {
        when: root.hasCurrent && root.currentName === "wirelesspassword"

        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    Content {
        id: popoutContent

        wrapper: root
    }

    SurfacePage {
        id: winfoPage

        surface: root
        current: root.detachedMode === "winfo"
        pageKey: "detached:winfo"
        hPadding: 0
        vPadding: 0

        sourceComponent: WindowInfo {
            screen: root.screen
            client: Compositor.activeWindow
        }
    }

    SurfacePage {
        id: sheetPage

        surface: root
        current: root.detachedMode === "any"
        pageKey: "detached:any"
        hPadding: 0
        vPadding: 0

        sourceComponent: ControlCenter {
            screen: root.screen
            active: root.queuedMode

            function close(): void {
                root.close();
            }
        }
    }
}
