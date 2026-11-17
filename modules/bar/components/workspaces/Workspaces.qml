pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

StyledClippingRect {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property ShellScreen screen

    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Owning bar edge (set by Bar.qml); drives which cell edge faces the
    // content for the §5 on-air bar / visible-elsewhere outline / tick.
    property string edge: Config.bar.positionFor(screen.name)
    // Per-entry options (docs/LAYOUTS.md). style "labels": workspace
    // numbers + app glyphs with an underline, no pill (Polybar lineage);
    // default "pills".
    property var options: ({})
    property bool clear: false
    readonly property bool labels: options?.style === "labels"
    readonly property bool niriMode: Compositor.isNiri
    readonly property bool onSpecial: Compositor.isSpecialWorkspaceActive(screen, Config.bar.workspaces.perMonitorWorkspaces)
    readonly property var activeWsId: niriMode
        ? Compositor.activeWorkspaceIdForScreen(screen)
        : Config.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId

    readonly property var workspaceItems: Compositor.workspacesForScreen(screen)
    readonly property var occupied: workspaceItems.reduce((acc, curr) => {
        acc[curr.id] = Compositor.workspaceHasWindows(curr);
        return acc;
    }, {})
    // §5 urgent: HyprlandWorkspace.urgent / niri is_urgent, keyed by ws id.
    readonly property var urgent: workspaceItems.reduce((acc, curr) => {
        acc[curr.id] = niriMode ? (curr.is_urgent ?? false) : (curr.urgent ?? false);
        return acc;
    }, {})
    // §5 visible on another monitor: active on some other output. Niri
    // workspaces are per-output, so this only applies under Hyprland.
    readonly property var visibleElsewhere: {
        if (niriMode || !Compositor.isHyprland)
            return {};
        const mine = Hypr.monitorFor(screen);
        const out = {};
        for (const mon of Hypr.monitors.values) {
            if (mine && mon.id === mine.id)
                continue;
            const id = mon.activeWorkspace?.id;
            if (id !== undefined && id !== null)
                out[id] = true;
        }
        return out;
    }
    readonly property int groupOffset: niriMode || activeWsId === null ? 0 : Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: onSpecial ? 1 : 0

    implicitWidth: vertical ? Config.bar.sizes.innerWidth : layout.implicitWidth + Appearance.padding.small * 2
    implicitHeight: vertical ? layout.implicitHeight + Appearance.padding.small * 2 : Config.bar.sizes.innerWidth

    // Cockpit Clear draws no fill behind any foreground group.
    color: labels || clear ? "transparent" : Signal.tPalette.panel
    // Signal Bezel §5: rectangular strip housing fixed cells, never a pill.
    radius: Appearance.rounding.small

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg && !root.labels && !root.niriMode && !root.clear

            anchors.fill: parent
            anchors.margins: Appearance.padding.small

            sourceComponent: OccupiedBg {
                screen: root.screen
                vertical: root.vertical
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        GridLayout {
            id: layout

            anchors.centerIn: parent
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            rowSpacing: root.labels ? Appearance.spacing.normal : Math.floor(Appearance.spacing.small / 2)
            columnSpacing: root.labels ? Appearance.spacing.normal : Math.floor(Appearance.spacing.small / 2)

            Repeater {
                id: workspaces

                model: root.niriMode ? root.workspaceItems : Config.bar.workspaces.shown

                Workspace {
                    screen: root.screen
                    niriMode: root.niriMode
                    workspaceData: root.niriMode ? modelData : null

                    vertical: root.vertical
                    edge: root.edge
                    tone: root.tone
                    labels: root.labels
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    urgent: root.urgent
                    visibleElsewhere: root.visibleElsewhere
                    groupOffset: root.groupOffset
                }
            }
        }

        // Labels style underline under each active/occupied workspace, on the
        // bar's inner side. Thickness carries state as well as colour.
        Repeater {
            model: root.labels ? workspaces.count : 0

            Rectangle {
                id: underline

                required property int index
                readonly property Item ws: workspaces.itemAt(index)
                readonly property bool isActive: ws?.isActive ?? false

                // §5: active carries the 2 px on-air bar; occupied is
                // carried by the cell tick, urgent by an alert bar.
                visible: !!ws && (isActive || ws.isUrgent)
                x: root.vertical ? layout.x + layout.width + 2 : layout.x + (ws?.x ?? 0)
                y: root.vertical ? layout.y + (ws?.y ?? 0) : layout.y + layout.height + 2
                width: root.vertical ? 2 : (ws?.width ?? 0)
                height: root.vertical ? (ws?.height ?? 0) : 2
                radius: 0
                color: isActive ? root.tone.signal : root.tone.alert

                Behavior on color {
                    CAnim {}
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
            active: Config.bar.workspaces.activeIndicator && !root.labels && !root.niriMode

            sourceComponent: ActiveIndicator {
                screen: root.screen
                vertical: root.vertical
                edge: root.edge
                tone: root.tone
                clear: root.clear
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent
        anchors.margins: Appearance.padding.small

        active: opacity > 0 && Compositor.capabilities.specialWorkspaces

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
            vertical: root.vertical
            tone: root.tone
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            duration: Appearance.anim.durations.short
        }
    }
}
