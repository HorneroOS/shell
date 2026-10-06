pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import qs.modules.bar
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData
        readonly property bool barDisabled: Strings.testRegexList(Config.bar.excludedScreens, modelData.name)

        Exclusions {
            screen: scope.modelData
            bar: bar
        }

        StyledWindow {
            id: win

            readonly property bool keyboardIntent: (visibilities.launcher && Config.launcher.enabled) || (visibilities.session && Config.session.enabled) || (visibilities.sidebar && Config.sidebar.enabled) || ((!Config.dashboard.showOnHover || interactions.dashboardKeyboardIntent) && visibilities.dashboard && Config.dashboard.enabled) || (interactions.utilitiesKeyboardIntent && visibilities.utilities && Config.utilities.enabled) || visibilities.layoutPicker || (panels.popouts.keyboardIntent && panels.popouts.hasCurrent) || (panels.popouts.currentName.startsWith("traymenu") && panels.popouts.current?.depth > 1)
            property var focusedWindowAtKeyboardIntent: null
            property var lastNiriOutsideClick: null
            readonly property bool hasFullscreen: Compositor.hasFullscreenOnScreen(screen)
            readonly property int dragMaskPadding: {
                if (keyboardIntent || panels.popouts.isDetached)
                    return 0;

                if (Compositor.isSpecialWorkspaceActive(screen, true) || Compositor.activeWorkspaceHasWindows(screen))
                    return 0;

                const thresholds = [];
                for (const panel of ["dashboard", "launcher", "session", "sidebar"])
                    if (Config[panel].enabled)
                        thresholds.push(Config[panel].dragThreshold);
                return Math.max(...thresholds);
            }

            onHasFullscreenChanged: {
                visibilities.launcher = false;
                visibilities.session = false;
                visibilities.dashboard = false;
                visibilities.sidebar = false;
                visibilities.utilities = false;
                visibilities.layoutPicker = false;
            }

            screen: scope.modelData
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // Keyboard interactivity follows the focus grab exactly
            // (#84). Niri does not give a top-layer OnDemand surface
            // keyboard focus when opened by a compositor shortcut, so
            // explicit drawer interactions need Exclusive there. Hyprland
            // uses OnDemand: Exclusive causes its focus-grab bounce for an
            // already-mapped surface. Hover-only surfaces stay None on both.
            WlrLayershell.keyboardFocus: keyboardIntent && Compositor.isNiri
                ? WlrKeyboardFocus.Exclusive
                : keyboardIntent ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Topmost keyboard-holding drawer, same order as
            // dismissTopmost(): Tab stays inside it (FocusMode.step).
            readonly property Item keyboardRoot: visibilities.layoutPicker ? panels.layoutPicker : visibilities.session ? panels.session : visibilities.launcher ? panels.launcher : (visibilities.dashboard && (!Config.dashboard.showOnHover || interactions.dashboardKeyboardIntent)) ? panels.dashboard : visibilities.sidebar ? panels.sidebar : (visibilities.utilities && interactions.utilitiesKeyboardIntent) ? panels.utilities : ((panels.popouts.keyboardIntent && panels.popouts.hasCurrent) || (panels.popouts.currentName.startsWith("traymenu") && panels.popouts.current?.depth > 1)) ? panels.popouts : null

            // One writer per window: publish this screen's root while its
            // grab holds the keyboard, clear it only if it is still ours.
            function syncFocusRoot(): void {
                if (keyboardIntent) {
                    FocusMode.currentRoot = win.keyboardRoot;
                    // Qt focus may still sit in another (hidden) drawer, e.g.
                    // the launcher search field; seed the new root so typed
                    // keys land in the drawer that holds the keyboard.
                    const current = win.contentItem.Window.activeFocusItem;
                    if (win.keyboardRoot && !(current && FocusMode.contains(win.keyboardRoot, current)))
                        Qt.callLater(() => FocusMode.enter(true));
                }
                else if (FocusMode.currentRoot && FocusMode.contains(win.contentItem, FocusMode.currentRoot))
                    FocusMode.currentRoot = null;
            }
            onKeyboardRootChanged: syncFocusRoot()
            onKeyboardIntentChanged: {
                focusedWindowAtKeyboardIntent = Compositor.isNiri && keyboardIntent ? Niri.focusedWindow?.id ?? null : null;
            }

            // Central Escape cascade (docs/INTERACTION.md). Content with
            // transient inner state (rename field, armed session action)
            // accepts the first Escape itself; anything unhandled lands
            // here and dismisses the topmost drawer. OSD clears
            // alongside: after Escape the surface holds no transient UI.
            function dismissTopmost(): void {
                if (visibilities.layoutPicker)
                    visibilities.layoutPicker = false;
                else if (visibilities.session && Config.session.enabled)
                    visibilities.session = false;
                else if (visibilities.launcher && Config.launcher.enabled)
                    visibilities.launcher = false;
                else if (visibilities.dashboard && Config.dashboard.enabled)
                    visibilities.dashboard = false;
                else if (visibilities.sidebar && Config.sidebar.enabled)
                    visibilities.sidebar = false;
                else if (visibilities.utilities && Config.utilities.enabled)
                    visibilities.utilities = false;
                else
                    return;
                visibilities.osd = false;
            }

            // Niri's layer-shell Exclusive mode receives explicit keyboard
            // intent, but an outside pointer click can still reach a window
            // beneath the layer. Close transient surfaces so the layer
            // releases the keyboard immediately.
            function dismissNiriTransientSurfaces(): void {
                visibilities.launcher = false;
                visibilities.session = false;
                visibilities.sidebar = false;
                visibilities.dashboard = false;
                visibilities.utilities = false;
                visibilities.layoutPicker = false;
                visibilities.osd = false;
                panels.popouts.keyboardIntent = false;
                panels.popouts.hasCurrent = false;
                bar.closeTray();
            }

            function pointerInsideKeyboardRoot(pointX: real, pointY: real): bool {
                const root = keyboardRoot;
                if (!root || !root.visible || root.width <= 0 || root.height <= 0)
                    return false;

                const origin = root.mapToItem(win.contentItem, 0, 0);
                return pointX >= origin.x && pointX <= origin.x + root.width && pointY >= origin.y && pointY <= origin.y + root.height;
            }

            Connections {
                target: Niri

                function onFocusedWindowChanged(): void {
                    const focusedWindow = Niri.focusedWindow;
                    // An Exclusive layer makes Niri report no focused
                    // toplevel while the drawer owns keyboard focus. Only a
                    // different real window should dismiss the transient.
                    if (Compositor.isNiri && win.keyboardIntent && focusedWindow && focusedWindow.id !== win.focusedWindowAtKeyboardIntent)
                        win.dismissNiriTransientSurfaces();
                }
            }

            mask: Region {
                regions: win.hasFullscreen ? [] : inputRegions.instances
            }

            // DEBUG overlay disabled for production
            // Item {
            //     id: debugOverlay
            //     anchors.fill: parent
            //     visible: false
            //     z: 999
            //     Repeater {
            //         model: inputRegions.model
            //         Rectangle {
            //             required property var modelData
            //             readonly property bool isEdge: modelData !== null && typeof modelData === "object" && modelData.isEdge === true
            //             x: isEdge ? modelData.x : modelData.x + bar.marginLeft
            //             y: isEdge ? modelData.y : modelData.y + bar.marginTop
            //             width: isEdge ? modelData.width : (modelData.width > 0 && modelData.height > 0 ? modelData.width : 0)
            //             height: isEdge ? modelData.height : (modelData.width > 0 && modelData.height > 0 ? modelData.height : 0)
            //             color: isEdge ? "#3000ff00" : "#60ff0000"
            //             border.color: isEdge ? "#8000ff00" : "#ffff0000"
            //             border.width: 2
            //         }
            //     }
            // }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: inputRegions

                model: {
                    if (win.hasFullscreen)
                        return [];
                    const trigger = Math.max(bar.frameInset, win.dragMaskPadding, 1);
                    const rects = [];
                    // Niri keeps Exclusive keyboard focus on a top-layer
                    // surface even when a pointer click reaches a window
                    // beneath it. Catch outside clicks on the same surface
                    // so the transient can close and release that focus.
                    if (Compositor.isNiri && win.keyboardIntent)
                        rects.push({ x: 0, y: 0, width: win.width, height: win.height, isEdge: true });
                    if (panels.popouts.isDetached) {
                        // Detached popouts grab all clicks so outside-clicks
                        // can close them (see Interactions.onPressed)
                        rects.push({
                            x: 0,
                            y: 0,
                            width: win.width,
                            height: win.height,
                            isEdge: true
                        });
                        return rects;
                    }
                    rects.push(
                        {
                            x: 0,
                            y: 0,
                            width: win.width,
                            height: trigger,
                            isEdge: true
                        },
                        {
                            x: 0,
                            y: win.height - trigger,
                            width: win.width,
                            height: trigger,
                            isEdge: true
                        },
                        {
                            x: 0,
                            y: trigger,
                            width: trigger,
                            height: Math.max(0, win.height - trigger * 2),
                            isEdge: true
                        },
                        {
                            x: win.width - trigger,
                            y: trigger,
                            width: trigger,
                            height: Math.max(0, win.height - trigger * 2),
                            isEdge: true
                        }
                    );

                    for (const r of bar.visualRects)
                        rects.push({
                            isEdge: true,
                            x: r.x,
                            y: r.y,
                            width: r.width,
                            height: r.height
                        });

                    // Panels as live Items for reactive geometry during animations
                    for (const p of panels.children)
                        rects.push(p);

                    // Bridge the breathing gap between a floating/clear bar and its
                    // open popout card, so moving the pointer from the trigger into
                    // the card never leaves the surface (which closes the popout).
                    const pop = panels.popouts;
                    if (pop.visible && !pop.isDetached && pop.width > 0 && pop.height > 0) {
                        const px = panels.x + pop.x;
                        const py = panels.y + pop.y;
                        switch (pop.ownerEdge) {
                        case "top":
                            rects.push({isEdge: true, x: px, y: bar.marginTop, width: pop.width, height: Math.max(0, py - bar.marginTop)});
                            break;
                        case "bottom":
                            rects.push({isEdge: true, x: px, y: py + pop.height, width: pop.width, height: Math.max(0, win.height - bar.marginBottom - py - pop.height)});
                            break;
                        case "left":
                            rects.push({isEdge: true, x: bar.marginLeft, y: py, width: Math.max(0, px - bar.marginLeft), height: pop.height});
                            break;
                        case "right":
                            rects.push({isEdge: true, x: px + pop.width, y: py, width: Math.max(0, win.width - bar.marginRight - px - pop.width), height: pop.height});
                            break;
                        }
                    }
                    return rects;
                }

                Region {
                    required property var modelData

                    readonly property bool isEdge: modelData !== null && typeof modelData === "object" && modelData.isEdge === true
                    // Panels live in the Panels item (bar margins plus the breathing
                    // gap next to floating/clear bars): map through its origin.
                    x: isEdge ? modelData.x : modelData.x + panels.x
                    y: isEdge ? modelData.y : modelData.y + panels.y
                    width: isEdge ? modelData.width : (modelData.width > 0 && modelData.height > 0 ? modelData.width : 0)
                    height: isEdge ? modelData.height : (modelData.width > 0 && modelData.height > 0 ? modelData.height : 0)
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: Compositor.isNiri && win.keyboardIntent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: mouse => {
                    const inside = win.pointerInsideKeyboardRoot(mouse.x, mouse.y);
                    const root = win.keyboardRoot;
                    const origin = root ? root.mapToItem(win.contentItem, 0, 0) : Qt.point(0, 0);
                    win.lastNiriOutsideClick = {
                        x: mouse.x,
                        y: mouse.y,
                        inside: inside,
                        root: root ? root.objectName || String(root).split("(")[0] : null,
                        rect: root ? [origin.x, origin.y, root.width, root.height] : null
                    };
                    if (!inside)
                        win.dismissNiriTransientSurfaces();
                }
            }

            HyprlandFocusGrab {
                id: focusGrab

                // The grab is what gives this surface compositor keyboard
                // focus (and with it Qt activation), so every drawer the
                // Escape cascade must dismiss needs grab coverage on its
                // keyboard-driven opens. Dashboard and utilities hover opens
                // stay grab-free so edge touches never steal typing; explicit
                // opens (shortcut, IPC, action — mouse outside the area) and
                // a click inside a hover-opened drawer set keyboard intent.
                active: Compositor.isHyprland && win.keyboardIntent
                windows: [win]
                onActiveChanged: win.syncFocusRoot()
                onCleared: {
                    visibilities.launcher = false;
                    visibilities.session = false;
                    visibilities.sidebar = false;
                    visibilities.dashboard = false;
                    visibilities.utilities = false;
                    visibilities.layoutPicker = false;
                    panels.popouts.hasCurrent = false;
                    bar.closeTray();
                }
            }

            StyledRect {
                anchors.fill: parent
                opacity: (visibilities.session && Config.session.enabled) || visibilities.layoutPicker ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                anchors.fill: parent
                // No window-level opacity: each backdrop carries its own
                // surface alpha (global base or per-surface override), so
                // element sliders never double-dim with this container.
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
                }

                Border {
                    bar: bar
                    visible: bar.frameVisible
                    opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
                }

                Backgrounds {
                    panels: panels
                    bar: bar
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities
                property bool sidebar
                property bool layoutPicker

                Component.onCompleted: Visibilities.load(scope.modelData, this)
            }

            // DEBUG: red borders on every panel + bar. Toggle with:
            //   qs ipc call debug borders
            Item {
                id: debugBorders

                anchors.fill: parent
                visible: false
                z: 1000

                // Bar wrapper (edge strip) — orange
                Rectangle {
                    x: bar.x
                    y: bar.y
                    width: bar.width
                    height: bar.height
                    color: "transparent"
                    border.color: "#FF8800"
                    border.width: 2
                }

                // Bar pill (visual extent) — bright red
                Rectangle {
                    x: bar.visualX
                    y: bar.visualY
                    width: bar.visualWidth
                    height: bar.visualHeight
                    color: "transparent"
                    border.color: "#FF2020"
                    border.width: 3
                }

                // Every panel (launcher, dashboard, session, sidebar,
                // utilities, notifications, popouts, osd, toasts...) — red
                Repeater {
                    model: panels.children

                    Rectangle {
                        required property Item modelData

                        x: modelData.x + panels.x
                        y: modelData.y + panels.y
                        width: modelData.width
                        height: modelData.height
                        color: "transparent"
                        border.color: "#FF2020"
                        border.width: 2
                    }
                }
            }

            IpcHandler {
                target: "debug"

                function borders(): string {
                    debugBorders.visible = !debugBorders.visible;
                    return debugBorders.visible ? "borders ON" : "borders OFF";
                }

                // S4 focus observability (docs/FOCUS.md): window
                // activation, input modality, grab state and the
                // active-focus chain. Graphical/agentic tests assert
                // on this instead of guessing from pixels. Kept
                // across the Exclusive revert: the keyboard-focus
                // redesign needs runtime observability.
                function focusState(): string {
                    const chain = [];
                    let it = win.contentItem.Window.activeFocusItem;
                    let guard = 0;
                    while (it && guard++ < 10) {
                        let tag = "?";
                        try {
                            tag = String(it).split("(")[0].split("_")[0];
                        } catch (e) {}
                        chain.push(`${tag}:${it.objectName || "?"}` + (it.activeFocus ? "*" : ""));
                        it = it.parent;
                    }
                    return JSON.stringify({
                        winActive: win.contentItem.Window.active,
                        inRoot: FocusMode.currentRoot ? FocusMode.contains(FocusMode.currentRoot, win.contentItem.Window.activeFocusItem) : null,
                        shown: FocusMode.currentRoot && win.contentItem.Window.activeFocusItem ? FocusMode.shown(FocusMode.currentRoot, win.contentItem.Window.activeFocusItem) : null,
                        focused: String(win.contentItem.Window.activeFocusItem ?? "none"),
                        root: FocusMode.currentRoot ? (FocusMode.currentRoot.objectName || String(FocusMode.currentRoot).split("(")[0]) : null,
                        keyboard: FocusMode.keyboard,
                        grab: focusGrab.active,
                        kbMode: win.WlrLayershell.keyboardFocus,
                        intent: { dashboard: interactions.dashboardKeyboardIntent, utilities: interactions.utilitiesKeyboardIntent },
                        lastNiriOutsideClick: win.lastNiriOutsideClick,
                        chain: chain.join(" < ") || "(null)"
                    });
                }

                function bars(): string {
                    return JSON.stringify(bar.bars.map(b => ({
                                    edge: b.position,
                                    style: b.style,
                                    geom: [b.x, b.y, b.width, b.height],
                                    visible: b.visible,
                                    shouldBeVisible: b.shouldBeVisible,
                                    rects: b.visualRects,
                                    islands: (b.children[0]?.item?.islands ?? []).map(i => ({
                                                align: i.align,
                                                geom: [i.x, i.y, i.width, i.height],
                                                visible: i.visible,
                                                groups: i.groupItems.map(g => [g.name, g.visible, g.width, g.height, g.x, g.y])
                                            }))
                                })));
                }

                function dump(): string {
                    const panelsDump = [];
                    for (const p of panels.children)
                        panelsDump.push({
                            name: p.objectName || String(p).split("_")[0],
                            x: p.x, y: p.y, width: p.width, height: p.height,
                            visible: p.visible
                        });
                    return JSON.stringify({
                        win: {w: win.width, h: win.height},
                        bar: {
                            x: bar.x, y: bar.y, w: bar.width, h: bar.height,
                            implicitW: bar.implicitWidth, implicitH: bar.implicitHeight,
                            position: bar.position, vertical: bar.vertical,
                            floating: bar.floating, thickness: bar.thickness,
                            currentThickness: bar.currentThickness,
                            pill: {x: bar.visualX, y: bar.visualY, w: bar.visualWidth, h: bar.visualHeight},
                        contentLoader: {
                            w: bar.children[0]?.width ?? -1, h: bar.children[0]?.height ?? -1,
                            itemW: bar.children[0]?.item?.width ?? -1, itemH: bar.children[0]?.item?.height ?? -1
                        },
                        pillDirect: {
                            w: bar.visualItem?.width ?? -1,
                            h: bar.visualItem?.height ?? -1,
                            floatGap: bar.visualItem?.floatGap ?? -999,
                            styleAttached: bar.visualItem?.styleAttached ?? "undef",
                            effStyle: bar.visualItem?.effStyle ?? "undef"
                        },
                        layout: {
                            w: bar.children[0]?.item?.container?.width ?? -1,
                            h: bar.children[0]?.item?.container?.height ?? -1,
                            implW: bar.children[0]?.item?.container?.implicitWidth ?? -1,
                            implH: bar.children[0]?.item?.container?.implicitHeight ?? -1,
                            x: bar.children[0]?.item?.container?.x ?? -1,
                            y: bar.children[0]?.item?.container?.y ?? -1
                        },
                            disabled: bar.disabled,
                        config: {
                            bars: Config.bar.barsFor("HDMI-A-1").map(b => ({edge: b.edge, style: b.style})),
                            styleFor: Config.bar.styleFor("HDMI-A-1"),
                            floatingFor: Config.bar.isFloatingFor("HDMI-A-1")
                        },
                        barFloating: bar.floating,
                        barStyleAttached: bar.styleAttached,
                        barEffStyle: bar.effStyle
                        },
                        popout: {
                            name: panels.popouts.currentName,
                            hasCurrent: panels.popouts.hasCurrent,
                            detached: panels.popouts.detachedMode
                        },
                        panelsMargins: {
                            left: bar.marginLeft, top: bar.marginTop,
                            right: bar.marginRight, bottom: bar.marginBottom
                        },
                        panels: panelsDump
                    });
                }
            }

            Interactions {
                id: interactions

                enabled: !win.hasFullscreen
                screen: scope.modelData
                popouts: panels.popouts
                visibilities: visibilities
                panels: panels
                bar: bar

                // Central Escape cascade endpoint: unhandled Escape from
                // any drawer content bubbles here (docs/INTERACTION.md).
                Keys.onEscapePressed: win.dismissTopmost()
                // Tab that no focusable handled (Qt focus still outside the
                // keyboard-holding drawer, e.g. after a click promoted a
                // hover open) enters the drawer at its first/last stop.
                Keys.onTabPressed: event => event.accepted = FocusMode.enter(!(event.modifiers & Qt.ShiftModifier))
                Keys.onBacktabPressed: event => event.accepted = FocusMode.enter(false)

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    bar: bar
                }

                // A click inside a hover-opened drawer is keyboard
                // intent (#84). Drawer content consumes presses before
                // parents see them, so a transparent overlay on top
                // observes them with a passive PointHandler, which
                // never blocks delivery to the controls beneath.
                Item {
                    // Sibling of Panels, never a child: the input mask
                    // is built from panels.children and must not grow.
                    anchors.fill: panels
                    z: 1000

                    PointHandler {
                        acceptedButtons: Qt.AllButtons
                        onActiveChanged: {
                            if (!active)
                                return;
                            const p = panels.mapToItem(interactions, point.position.x, point.position.y);
                            if (visibilities.dashboard && interactions.inTopPanel(panels.dashboard, p.x, p.y))
                                interactions.dashboardKeyboardIntent = true;
                            if (visibilities.utilities && interactions.inBottomPanel(panels.utilities, p.x, p.y))
                                interactions.utilitiesKeyboardIntent = true;
                        }
                    }
                }

                BarSet {
                    id: bar

                    anchors.fill: parent

                    screen: scope.modelData
                    visibilities: visibilities
                    popouts: panels.popouts

                    disabled: scope.barDisabled || win.hasFullscreen
                    frameVisible: Config.border.frameEnabled && !win.hasFullscreen

                    Component.onCompleted: Visibilities.setBar(scope.modelData, this)
                }
            }
        }
    }
}
