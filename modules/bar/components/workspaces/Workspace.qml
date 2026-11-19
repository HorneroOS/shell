import "../../../keybinds"
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property ShellScreen screen

    required property int index
    required property var activeWsId
    required property var occupied
    required property int groupOffset
    required property var modelData

    // Cross-axis size of one cell (Workspaces.cellCross); set by Workspaces.
    property int cellCross: Density.inner - Appearance.padding.small * 2

    property bool niriMode: false
    property var workspaceData: null

    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Owning bar edge; §5 cell marks sit on/away from the content edge.
    property string edge: Config.bar.positionFor(screen.name)
    // §5 state maps keyed by workspace id (set by Workspaces).
    property var urgent: ({})
    property var visibleElsewhere: ({})
    // Labels style: always the workspace number, plus an underline (accent
    // when active, faint when occupied). Set by Workspaces.
    property bool labels: false
    // Cell plates are drawn by CellPlates (under the active mark); without
    // them (Cockpit Clear, labels style) the cell carries its own marks.
    property bool plated: false
    // The sliding plate inks the numeral it covers (PlateInk), so the
    // active numeral keeps its resting colour underneath.
    property bool inkThrough: false
    // Special workspace open: the strip recedes to inkMuted.
    property bool receded: false
    // Hidden empty cell (bar.workspaces.showUnoccupied off).
    property bool hidden: false
    // A dimension break sits before this cell (non-contiguous numbers).
    property bool gapBefore: false
    // Extra main-axis room before the cell for the break mark (GapBreaks).
    readonly property int breakSpace: gapBefore ? Math.max(6, Math.round(Density.textPx * 0.75)) : 0
    readonly property bool isActive: activeWsId === ws
    readonly property bool isUrgent: !isActive && (niriMode ? (workspaceData?.is_urgent ?? false) : (urgent[ws] ?? false))
    readonly property bool isVisibleElsewhere: !isActive && (visibleElsewhere[ws] ?? false)
    // The cell edge facing the desktop content, per owning bar edge.
    readonly property bool contentAtTop: edge === "bottom"
    readonly property bool contentAtLeft: edge === "right"
    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property string accessibleState: root.isActive ? qsTr("current") : root.isUrgent ? qsTr("urgent") : root.isVisibleElsewhere ? qsTr("visible on another monitor") : root.isOccupied ? qsTr("occupied") : qsTr("empty")
    // Main-axis size of the cell, unanimated, for others to use as reference.
    readonly property int size: root.mainSize

    readonly property var ws: niriMode ? workspaceData?.id : groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows
    readonly property var windowItems: Compositor.windowsForWorkspace(ws)

    // Cell rhythm (docs/LAYOUTS.md, "Workspace cells"): every cell is `cellCross`
    // tall (wide on rails). The numeral sits in a square box of at least
    // `cellCross`; window glyphs follow after a fixed gap, one fixed-size slot
    // each, so a cell grows by exactly one step per glyph and nothing overlaps.
    readonly property int maxGlyphs: Math.max(0, Config.bar.workspaces.maxWindowIcons)
    readonly property int glyphCount: hasWindows ? Math.min(windowItems.length, maxGlyphs) : 0
    readonly property int overflowCount: hasWindows && maxGlyphs > 0 ? Math.max(0, windowItems.length - maxGlyphs) : 0
    // Glyphs sit at numeral x-height scale and always fit the cross axis.
    readonly property int glyphPx: Math.max(8, Math.min(Math.round(Density.textPx * Config.bar.workspaces.glyphScale / 100), root.cellCross - 4))
    readonly property int glyphGap: Math.max(1, Math.round(root.glyphPx / 8))
    readonly property int numeralGap: Math.max(2, Math.round(Density.textPx / 4))
    readonly property int edgePad: Math.max(2, Math.round(Density.textPx / 4))
    // The widest numeral the strip can show ("00" from ten workspaces), so
    // every cell shares one numeral box whatever its digit count.
    readonly property real numeralExtent: Math.ceil(Math.max(root.vertical ? ref.tightBoundingRect.height : ref.tightBoundingRect.width, root.vertical ? 0 : indicator.contentWidth))
    readonly property int numeralBox: Math.max(root.cellCross, root.numeralExtent + root.edgePad * 2)
    readonly property int groupStart: Math.ceil((root.numeralBox + root.numeralExtent) / 2) + root.numeralGap
    readonly property bool hasGlyphs: root.glyphCount > 0
    readonly property int mainSize: root.hasGlyphs ? root.groupStart + Math.ceil(root.vertical ? group.implicitHeight : group.implicitWidth) + root.edgePad : root.numeralBox

    // Geometry for the offscreen render check (tests/render).
    // (the numeral's ink extent, not its line box)
    readonly property real numeralW: indicator.contentWidth
    readonly property real numeralH: ref.tightBoundingRect.height
    readonly property real numeralX: indicator.x + (indicator.width - numeralW) / 2
    readonly property real numeralY: indicator.y + (indicator.height - numeralH) / 2
    readonly property real groupX: group.x
    readonly property real groupY: group.y
    readonly property real groupW: group.width
    readonly property real groupH: group.height
    // The numeral item, copied in ink by PlateInk.
    readonly property Item numeral: indicator

    function iconForWindow(window: var): string {
        const appId = niriMode ? window.app_id : window.lastIpcObject.class;
        return Icons.getAppCategoryIcon(appId, "terminal");
    }

    visible: !root.hidden
    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.leftMargin: vertical ? 0 : root.breakSpace
    Layout.topMargin: vertical ? root.breakSpace : 0
    Layout.preferredHeight: vertical ? size : implicitHeight
    Layout.preferredWidth: vertical ? implicitWidth : size
    implicitWidth: vertical ? root.cellCross : root.mainSize
    implicitHeight: vertical ? root.mainSize : root.cellCross

    TextMetrics {
        id: ref

        font.family: Density.dataFamily
        font.weight: Density.textWeight
        font.features: ({
                "tnum": 1
            })
        font.pointSize: Density.textPt
        text: Config.bar.workspaces.shown >= 10 ? "00" : "0"
    }

    StyledText {
        id: indicator

        x: root.vertical ? Math.round((root.width - width) / 2) : Math.round((root.numeralBox - width) / 2)
        y: root.vertical ? Math.round((root.numeralBox - height) / 2) : Math.round((root.height - height) / 2)

        animate: true
        font.family: Density.dataFamily
        font.weight: Density.textWeight
        font.features: ({
                "tnum": 1
            })
        font.pointSize: Density.textPt
        text: {
            if (root.niriMode) {
                const nativeLabel = Compositor.workspaceLabel(root.workspaceData, root.ws);
                return root.labels ? nativeLabel : root.isActive ? (Config.bar.workspaces.activeLabel || nativeLabel) : root.isOccupied ? (Config.bar.workspaces.occupiedLabel || Config.bar.workspaces.label || nativeLabel) : (Config.bar.workspaces.label || nativeLabel);
            }
            const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
            const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
            let displayName = wsName.toString();
            if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                displayName = displayName.toUpperCase();
            } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                displayName = displayName.toLowerCase();
            }
            if (root.labels)
                return displayName;
            const label = Config.bar.workspaces.label || displayName;
            const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
            const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
            return root.activeWsId === root.ws ? activeLabel : root.isOccupied ? occupiedLabel : label;
        }
        color: root.numeralColor
        verticalAlignment: Qt.AlignVCenter
        horizontalAlignment: Qt.AlignHCenter
    }

    // §5: urgent numeral in alert; active and visible-elsewhere in ink;
    // occupied and empty in inkMuted (the plate or tick carries the rest).
    readonly property color numeralColor: {
        if (root.isUrgent)
            return root.tone.alert;
        if (root.receded)
            return root.tone.inkMuted;
        if (root.labels)
            return root.isActive ? root.tone.signal : root.isOccupied ? root.tone.ink : root.tone.inkMuted;
        if (root.isActive && root.inkThrough)
            return root.tone.inkMuted;
        return root.isActive || root.isVisibleElsewhere ? root.tone.ink : root.tone.inkMuted;
    }

    // Window glyphs: fixed-size slots after the numeral, then a +N mark when
    // more windows are open than `maxWindowIcons`.
    Grid {
        id: group

        visible: root.hasGlyphs
        x: root.vertical ? Math.round((root.width - width) / 2) : root.groupStart
        y: root.vertical ? root.groupStart : Math.round((root.height - height) / 2)
        columns: root.vertical ? 1 : 64
        spacing: root.glyphGap

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing.bezierCurve: Appearance.anim.curves.enter
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing.bezierCurve: Appearance.anim.curves.enter
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.windowItems.slice(0, root.hasGlyphs ? root.glyphCount : 0)
            }

            Item {
                required property var modelData

                width: root.glyphPx
                height: root.glyphPx

                Glyph {
                    anchors.centerIn: parent
                    size: Density.pt(root.glyphPx)
                    name: root.iconForWindow(parent.modelData)
                    color: root.isActive && !root.receded ? root.tone.ink : root.tone.inkMuted
                }
            }
        }

        Item {
            visible: root.overflowCount > 0
            width: Math.max(root.glyphPx, more.implicitWidth)
            height: root.glyphPx

            StyledText {
                id: more

                anchors.centerIn: parent
                font.family: Density.dataFamily
                font.weight: Density.textWeight
                font.pointSize: Density.pt(Math.max(8, root.glyphPx - 1))
                text: "+" + root.overflowCount
                color: root.isActive && !root.receded ? root.tone.ink : root.tone.inkMuted
            }
        }
    }

    // §5 occupancy tick: 4 x 2 px under the numeral, 2 px from the edge away
    // from the content. Alert-coloured while urgent. Plated cells show occupancy as
    // their plate instead (CellPlates).
    Rectangle {
        visible: root.isOccupied && !root.isActive && !root.plated
        width: root.vertical ? 2 : 4
        height: root.vertical ? 4 : 2
        x: root.vertical ? (root.contentAtLeft ? root.width - width - 2 : 2) : Math.round((root.numeralBox - width) / 2)
        y: root.vertical ? Math.round((root.numeralBox - height) / 2) : (root.contentAtTop ? root.height - height - 2 : 2)
        color: root.isUrgent ? root.tone.alert : root.tone.inkMuted

        Behavior on color {
            CAnim {}
        }
    }

    // §5 visible on another monitor: a short 2 px mark centred on the
    // content-facing edge (never an outline, so it cannot read as active).
    Rectangle {
        visible: root.isVisibleElsewhere
        readonly property real len: Math.max(4, Math.round(root.numeralBox / 3))
        width: root.vertical ? 2 : len
        height: root.vertical ? len : 2
        x: root.vertical ? (root.contentAtLeft ? 1 : root.width - 3) : Math.round((root.numeralBox - width) / 2)
        y: root.vertical ? Math.round((root.numeralBox - height) / 2) : (root.contentAtTop ? 1 : root.height - 3)
        radius: 1 // fixed: 2 px tick end rounding, not a theme corner
        color: root.tone.active ? root.tone.inkMuted : Signal.palette.ruleStrong
    }

    // SUPER-hold key badge (#701): while bare SUPER is held past the
    // configured delay, the cell shows the key that focuses it (from
    // the live bind list, so rebinds move the badge). Purely visual:
    // it never takes input, and Keybinds.badgesVisible owns the timing.
    Keycap {
        visible: Keybinds.badgesVisible && text !== ""
        text: Keybinds.workspaceBadge(root.ws)
        accent: true
        compact: true
        z: 2
        x: (root.vertical ? root.width : root.numeralBox) - width - 1
        y: 1
    }

    Interactive {
        anchors.fill: parent

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Workspace %1, %2").arg(root.niriMode ? Compositor.workspaceLabel(root.workspaceData, root.ws) : root.ws).arg(root.accessibleState)
        Accessible.description: root.isActive && !root.niriMode ? qsTr("Activating the current workspace opens the special workspace") : qsTr("Switch to workspace %1").arg(root.ws)

        onClicked: {
            if (root.activeWsId !== root.ws)
                Compositor.focusWorkspace(root.niriMode ? root.workspaceData : ({ id: root.ws }));
            else if (!root.niriMode)
                Compositor.toggleSpecialWorkspace();
        }
    }

    Behavior on Layout.preferredHeight {
        Anim {}
    }

    Behavior on Layout.preferredWidth {
        Anim {}
    }
}
