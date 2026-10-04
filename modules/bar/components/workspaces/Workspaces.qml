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

    required property ShellScreen screen

    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
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
    readonly property int groupOffset: niriMode || activeWsId === null ? 0 : Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: onSpecial ? 1 : 0

    implicitWidth: vertical ? Config.bar.sizes.innerWidth : layout.implicitWidth + Appearance.padding.small * 2
    implicitHeight: vertical ? layout.implicitHeight + Appearance.padding.small * 2 : Config.bar.sizes.innerWidth

    color: labels ? "transparent" : Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full

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
            active: Config.bar.workspaces.occupiedBg && !root.labels && !root.niriMode

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
                    labels: root.labels
                    activeWsId: root.activeWsId
                    occupied: root.occupied
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

                visible: !!ws && (isActive || ws.isOccupied)
                x: root.vertical ? layout.x + layout.width + 2 : layout.x + (ws?.x ?? 0)
                y: root.vertical ? layout.y + (ws?.y ?? 0) : layout.y + layout.height + 2
                width: root.vertical ? (isActive ? 3 : 2) : (ws?.width ?? 0)
                height: root.vertical ? (ws?.height ?? 0) : (isActive ? 3 : 2)
                radius: Appearance.rounding.full
                color: isActive ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

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
            duration: Appearance.anim.durations.small
        }
    }
}
