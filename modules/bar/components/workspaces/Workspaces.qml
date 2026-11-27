pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import Quickshell
import QtQuick
import QtQuick.Layouts

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
    // Cell plates (empty hairline, occupied plate); never on Clear or labels.
    readonly property bool plated: Config.bar.workspaces.occupiedBg && !labels && !clear
    readonly property bool niriMode: Compositor.isNiri
    readonly property bool onSpecial: Compositor.isSpecialWorkspaceActive(screen, Config.bar.workspaces.perMonitorWorkspaces)
    readonly property var activeWsId: Compositor.activeWorkspaceIdForScreen(screen, Config.bar.workspaces.perMonitorWorkspaces)

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
    readonly property var visibleElsewhere: Compositor.workspacesVisibleElsewhere(screen)
    readonly property int groupOffset: niriMode || activeWsId === null ? 0 : Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    // Special workspace open: the strip recedes (dims to inkMuted and steps
    // 2 px away from the content), never scaled or blurred (SVL: content is
    // never scaled).
    readonly property bool receded: onSpecial
    readonly property int recedeShift: 2
    readonly property real recedeX: !receded || !vertical ? 0 : edge === "right" ? recedeShift : -recedeShift
    readonly property real recedeY: !receded || vertical ? 0 : edge === "top" ? -recedeShift : recedeShift

    // Strip cells by model order: their ids and the numbers they read as.
    readonly property var cellIds: niriMode ? workspaceItems.map(w => w.id) : Array.from({
            length: Config.bar.workspaces.shown
        }, (_, i) => groupOffset + i + 1)
    readonly property var cellNumbers: niriMode ? workspaceItems.map(w => w.idx ?? w.id) : cellIds
    // Cells shown: every one, or (showUnoccupied off) only the active,
    // occupied, urgent and visible-elsewhere ones.
    readonly property var shownCells: {
        const all = Config.bar.workspaces.showUnoccupied;
        const out = {};
        for (const id of cellIds)
            out[id] = all || id === activeWsId || (occupied[id] ?? false) || (urgent[id] ?? false) || (visibleElsewhere[id] ?? false);
        return out;
    }
    // Ids with a dimension break before them: the shown numbers jump.
    readonly property var gapBefore: {
        const out = {};
        if (!Config.bar.workspaces.gapBreaks)
            return out;
        let prev = null;
        for (let i = 0; i < cellIds.length; i++) {
            const id = cellIds[i];
            if (!shownCells[id])
                continue;
            const n = cellNumbers[i];
            if (prev !== null && n - prev > 1)
                out[id] = true;
            prev = n;
        }
        return out;
    }
    // The sliding active plate (needle travel). In the labels style (Cockpit
    // Clear's strip) it stays invisible and only lends its travelling
    // geometry to the active underline: foreground only.
    readonly property bool needleActive: Config.bar.workspaces.activeIndicator && !root.niriMode

    // Track cross-axis size (Density.chip, set by Bar.qml) and the cell
    // inside it: the active highlight keeps `activeInset` from the track
    // edges (Bars > Size & shape), so it never touches the island border.
    property int cross: Density.inner
    readonly property int activeInset: Density.activeInset(cross)
    readonly property int cellCross: cross - activeInset * 2

    implicitWidth: vertical ? cross : layout.implicitWidth + Appearance.padding.small * 2
    implicitHeight: vertical ? layout.implicitHeight + Appearance.padding.small * 2 : cross

    // Cockpit Clear draws no fill behind any foreground group.
    color: labels || clear ? "transparent" : Signal.tPalette.panel
    // Signal Bezel §5: rectangular strip housing fixed cells, never a pill.
    radius: Appearance.rounding.small

    Item {
        id: strip

        anchors.fill: parent
        opacity: root.receded ? 0.55 : 1

        transform: Translate {
            x: root.recedeX
            y: root.recedeY

            Behavior on x {
                Anim {}
            }

            Behavior on y {
                Anim {}
            }
        }

        // Cell plates and the sliding active plate sit under the numerals.
        Loader {
            active: root.plated

            anchors.fill: parent

            sourceComponent: CellPlates {
                tone: root.tone
                workspaces: workspaces
                cells: layout
                markActive: root.niriMode || !Config.bar.workspaces.activeIndicator
            }
        }

        Loader {
            id: plateLoader

            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
            active: root.needleActive

            sourceComponent: ActiveIndicator {
                screen: root.screen
                vertical: root.vertical
                edge: root.edge
                tone: root.tone
                clear: root.clear
                receded: root.receded
                visible: !root.labels
                inset: root.activeInset
                crossSize: root.cross
                activeWsId: root.activeWsId
                workspaces: workspaces
                cells: layout
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
                    id: cell

                    screen: root.screen
                    niriMode: root.niriMode
                    workspaceData: root.niriMode ? modelData : null

                    vertical: root.vertical
                    edge: root.edge
                    cellCross: root.cellCross
                    tone: root.tone
                    labels: root.labels
                    plated: root.plated
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    urgent: root.urgent
                    visibleElsewhere: root.visibleElsewhere
                    groupOffset: root.groupOffset
                    inkThrough: root.needleActive && !root.labels
                    receded: root.receded
                    hidden: !(root.shownCells[cell.ws] ?? true)
                    gapBefore: root.gapBefore[cell.ws] ?? false
                }
            }
        }

        // Numerals under the plate in ink, over the strip (needle travel).
        Loader {
            anchors.fill: parent
            active: root.needleActive && !root.labels

            sourceComponent: PlateInk {
                tone: root.tone
                receded: root.receded
                plate: plateLoader.item
                plateHost: plateLoader
                workspaces: workspaces
                cells: layout
            }
        }

        GapBreaks {
            anchors.fill: parent
            tone: root.tone
            vertical: root.vertical
            workspaces: workspaces
            cells: layout
            spacing: root.vertical ? layout.rowSpacing : layout.columnSpacing
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

                // §5: active carries the 2 px on-air bar (the travelling
                // one below when the plate is loaded); occupied is carried
                // by the cell tick, urgent by an alert bar.
                visible: !!ws && ws.visible && ((isActive && !plateLoader.item) || ws.isUrgent)
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

        // Labels style active underline: rides the plate's travelling edges,
        // so it stretches toward the target and lands under one cell.
        Rectangle {
            readonly property Item plate: root.labels ? plateLoader.item : null

            visible: !!plate
            x: root.vertical ? layout.x + layout.width + 2 : layout.x + (plate?.startEdge ?? 0)
            y: root.vertical ? layout.y + (plate?.startEdge ?? 0) : layout.y + layout.height + 2
            width: root.vertical ? 2 : (plate?.length ?? 0)
            height: root.vertical ? (plate?.length ?? 0) : 2
            radius: 0 // fixed: square 2 px on-air bar, like the per-cell one
            color: root.receded ? root.tone.inkMuted : root.tone.signal

            Behavior on color {
                CAnim {}
            }
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

        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
            vertical: root.vertical
            cellCross: root.cellCross
            tone: root.tone
        }

        Behavior on opacity {
            Anim {}
        }
    }
}
