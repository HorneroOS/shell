pragma ComponentBehavior: Bound

import qs.components
import qs.components.motion
import qs.services
import qs.config
import Hornero.PluginKit as Kit
import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// One desktop widget (PluginKit 3, RFC 0001 §5b): a Signal instrument
// module — `panel` fill, 1 px `rule` border, radius 3, the single
// elevation shadow, an eyebrow header (`02 · SYSTEM INSIGHT`) — holding
// the extension's desktop entrypoint in its own Loader, so a failing
// widget never takes the desktop or its neighbours down.
//
// The host owns geometry: the widget starts at its anchor (the person's
// Control Center choice, else the manifest hint) with the manifest's
// default size, and in edit mode the person drags it (8 px grid) and
// resizes it from the corner grip. Geometry is saved per screen as a
// fraction of the free space, so a resolution change keeps the layout.
//
// In the `signal` experience the module gains registration marks at its
// corners (framed instrument composition); they are drawn with
// `ruleStrong` hairlines and never glow.
Item {
    id: root

    required property var entry
    required property string screenName
    required property Item area
    required property int channel
    // Signal deck: the placement services/deck.js computed for this
    // screen ({x, y, width, height, fx, fy}), or null for a user widget.
    // Deck geometry is persisted per experience mode (Experience.
    // setDeckGeometry), never in the user's everyday widget layout.
    property var deckPlacement: null
    // Collision-free first-run slot chosen by PluginDesktopWidgets; used
    // when the person has not picked an anchor (never overrides one).
    property string defaultSlot: ""
    readonly property bool deck: root.deckPlacement !== null

    readonly property string pluginId: entry.id
    readonly property var hint: Plugins.surfaceFor(entry, "desktop") ?? ({})
    readonly property var saved: root.deck ? ({
            fx: root.deckPlacement.fx,
            fy: root.deckPlacement.fy,
            width: root.deckPlacement.width,
            height: root.deckPlacement.height
        }) : Config.plugins.desktopWidgetGeometry(root.pluginId, root.screenName)
    readonly property string anchorSlot: {
        const slots = Config.plugins.desktopWidgetSlots;
        const perScreen = slots && typeof slots === "object" ? slots[root.screenName || "default"] : null;
        const explicit = perScreen && typeof perScreen === "object" ? perScreen[root.pluginId] : undefined;
        return Config.plugins.allowedDesktopSlots.includes(explicit) ? explicit : (Config.plugins.allowedDesktopSlots.includes(root.defaultSlot) ? root.defaultSlot : (Config.plugins.allowedDesktopSlots.includes(root.hint.anchor) ? root.hint.anchor : "bottom-right"));
    }
    readonly property bool editing: Plugins.desktopEditing
    readonly property bool resizable: root.hint.resizable !== false
    readonly property bool signalMode: Kit.Theme.experience === "signal" || root.deck
    // Experience profile (RFC §5a): `none` (focus, gaming) hides desktop
    // widgets and unloads them, so they cost nothing; gaming under a
    // fullscreen window also suspends them.
    readonly property bool suspended: Experience.desktopWidgets === "none" || !Experience.desktopWidgetsVisible

    readonly property int padding: Appearance.padding.larger
    readonly property int headerHeight: 28
    readonly property int minWidth: root.hint.minWidth ?? 160
    readonly property int minHeight: root.hint.minHeight ?? 96
    // Size: saved → manifest default → content's implicit size.
    readonly property int naturalWidth: root.saved?.width ?? root.hint.width ?? Math.max(root.minWidth, (pluginLoader.item?.implicitWidth ?? 240) + root.padding * 2)
    readonly property int naturalHeight: root.saved?.height ?? root.hint.height ?? Math.max(root.minHeight, (pluginLoader.item?.implicitHeight ?? 120) + root.headerHeight + root.padding * 2)
    readonly property int frameWidth: Math.min(root.area.width, Math.max(root.minWidth, root._resizing ? root._liveWidth : root.naturalWidth))
    readonly property int frameHeight: Math.min(root.area.height, Math.max(root.minHeight, root._resizing ? root._liveHeight : root.naturalHeight))
    // Position: saved fraction → anchor.
    readonly property real fx: root.saved?.fx ?? (root.anchorSlot.endsWith("left") ? 0 : root.anchorSlot.endsWith("right") ? 1 : 0.5)
    readonly property real fy: root.saved?.fy ?? (root.anchorSlot.startsWith("top") ? 0 : root.anchorSlot.startsWith("bottom") ? 1 : 0.5)

    property bool _dragging: false
    property bool _resizing: false
    property real _liveWidth: 0
    property real _liveHeight: 0

    visible: !root.suspended

    // Scan-in (RFC §3.6): deck modules fade in with the shared stagger and
    // a short travel from the nearest side; motion level `off` shows them
    // at once. Leaving the mode fades the whole deck layer (host).
    property bool _revealed: !root.deck
    opacity: root._revealed ? 1 : 0
    transform: Translate {
        x: root._revealed ? 0 : (root.fx < 0.5 ? -1 : 1) * Choreography.scanTravel

        Behavior on x {
            NumberAnimation {
                duration: Choreography.fadeIn
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Choreography.curves.enter
            }
        }
    }

    Behavior on opacity {
        enabled: root.deck
        FadeAnim {}
    }

    Timer {
        running: root.deck && !root._revealed
        interval: Math.max(1, Choreography.rowDelay(root.channel - 1))
        onTriggered: root._revealed = true
    }
    readonly property real _homeX: Math.round(root.fx * Math.max(0, root.area.width - root.frameWidth))
    readonly property real _homeY: Math.round(root.fy * Math.max(0, root.area.height - root.frameHeight))

    x: root._homeX
    y: root._homeY
    width: root.frameWidth
    height: root.frameHeight

    function _snap(v: real): real {
        return Math.round(v / 8) * 8;
    }

    function _persist(nx: real, ny: real, w: real, h: real): void {
        const freeW = Math.max(1, root.area.width - w);
        const freeH = Math.max(1, root.area.height - h);
        const geometry = {
            fx: root.area.width - w <= 0 ? 0 : nx / freeW,
            fy: root.area.height - h <= 0 ? 0 : ny / freeH,
            width: Math.round(w),
            height: Math.round(h)
        };
        if (root.deck)
            Experience.setDeckGeometry(root.screenName, root.pluginId, geometry);
        else
            Config.plugins.setDesktopWidgetGeometry(root.pluginId, root.screenName, geometry, true);
    }

    RectangularShadow {
        anchors.fill: frame
        offset.y: 4
        blur: 12
        radius: frame.radius
        color: Qt.alpha(Signal.palette.shadow, 0.35)
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Signal.palette.panel
        border.width: 1
        border.color: Signal.palette.rule

        // Header: channel eyebrow + context eyebrow.
        StyledText {
            id: title

            x: root.padding
            y: Math.round((root.headerHeight - height) / 2) + 4
            mono: true
            font.pointSize: Appearance.font.size.small
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Appearance.font.size.small * 0.08
            color: Signal.palette.inkMuted
            text: `${String(root.channel).padStart(2, "0")} · ${pluginLoader.item?.widgetTitle || root.entry.name || root.pluginId}`
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width - root.padding * 2 - context.implicitWidth - Appearance.spacing.larger)
        }

        StyledText {
            id: context

            anchors.right: parent.right
            anchors.rightMargin: root.padding
            anchors.verticalCenter: title.verticalCenter
            mono: true
            font.pointSize: Appearance.font.size.small
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Appearance.font.size.small * 0.08
            color: Signal.palette.inkMuted
            text: pluginLoader.item?.widgetContext ?? ""
        }

        Loader {
            id: pluginLoader

            // Host context, the same injection contract as the bar and
            // dashboard hosts (docs/PLUGINS.md "Host context").
            readonly property int hostAvailableWidth: Math.max(0, root.width - root.padding * 2)
            readonly property int hostAvailableHeight: Math.max(0, root.height - root.headerHeight - root.padding * 2)

            x: root.padding
            y: root.headerHeight + Appearance.spacing.small
            width: hostAvailableWidth
            height: hostAvailableHeight
            clip: true
            palette.windowText: Signal.palette.ink
            active: !root.suspended && !!root.entry.entrypoint
            asynchronous: true
            // pluginsForSurface hands the desktop surface's file in entrypoint.
            source: root.entry.entrypoint ? `file://${Plugins.pluginsDir}/${root.pluginId}/${root.entry.entrypoint}` : ""
            enabled: !root.editing

            onStatusChanged: {
                if (status === Loader.Loading)
                    Plugins.markLoading(root.pluginId);
                else if (status === Loader.Ready)
                    Plugins.markLoaded(root.pluginId, "desktop");
                else if (status === Loader.Error)
                    Plugins.markFailed(root.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "desktop entrypoint failed to load (see shell log)", "desktop");
            }

            Binding {
                target: pluginLoader.item
                property: "hostSurface"
                value: "desktop"
                when: pluginLoader.item !== null && "hostSurface" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostOrientation"
                value: "horizontal"
                when: pluginLoader.item !== null && "hostOrientation" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostEdge"
                value: "none"
                when: pluginLoader.item !== null && "hostEdge" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostAvailableWidth"
                value: pluginLoader.hostAvailableWidth
                when: pluginLoader.item !== null && "hostAvailableWidth" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostAvailableHeight"
                value: pluginLoader.hostAvailableHeight
                when: pluginLoader.item !== null && "hostAvailableHeight" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostCompact"
                value: pluginLoader.hostAvailableWidth < 280
                when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: pluginLoader.item
                property: "hostScreenName"
                value: root.screenName
                when: pluginLoader.item !== null && "hostScreenName" in pluginLoader.item
                restoreMode: Binding.RestoreNone
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: pluginLoader.status === Loader.Error
            text: qsTr("This widget failed to load.")
            color: Signal.palette.alert
        }
    }

    // Signal experience: registration marks framing the module.
    Repeater {
        model: root.signalMode && !root.editing ? 4 : 0

        delegate: Item {
            id: mark

            required property int index
            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atBottom: index >= 2

            x: atRight ? root.width + 3 - 10 : -3
            y: atBottom ? root.height + 3 - 10 : -3
            width: 10
            height: 10

            Rectangle {
                x: mark.atRight ? mark.width - 1 : 0
                width: 1
                height: mark.height
                color: Signal.palette.ruleStrong
            }

            Rectangle {
                y: mark.atBottom ? mark.height - 1 : 0
                width: mark.width
                height: 1
                color: Signal.palette.ruleStrong
            }
        }
    }

    // Edit mode: dashed `cue` outline, whole-module drag, corner grip,
    // live dimension readout.
    Shape {
        anchors.fill: parent
        anchors.margins: -4
        visible: root.editing

        ShapePath {
            strokeColor: Signal.palette.cue
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 3]
            fillColor: "transparent"
            startX: 0.5
            startY: 0.5

            PathLine {
                x: root.width + 7.5
                y: 0.5
            }
            PathLine {
                x: root.width + 7.5
                y: root.height + 7.5
            }
            PathLine {
                x: 0.5
                y: root.height + 7.5
            }
            PathLine {
                x: 0.5
                y: 0.5
            }
        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        visible: root.editing
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: Math.max(0, root.area.width - root.width)
        drag.maximumY: Math.max(0, root.area.height - root.height)
        drag.threshold: 2

        onPressed: root._dragging = true
        onReleased: {
            const nx = Math.max(0, Math.min(root.area.width - root.width, root._snap(root.x)));
            const ny = Math.max(0, Math.min(root.area.height - root.height, root._snap(root.y)));
            root._persist(nx, ny, root.width, root.height);
            root._dragging = false;
            // Dragging replaced the bindings; follow the saved geometry again.
            root.x = Qt.binding(() => root._homeX);
            root.y = Qt.binding(() => root._homeY);
        }
        onCanceled: {
            root._dragging = false;
            root.x = Qt.binding(() => root._homeX);
            root.y = Qt.binding(() => root._homeY);
        }

        Accessible.role: Accessible.Grip
        Accessible.name: qsTr("Move %1").arg(root.entry.name || root.pluginId)
    }

    // Corner resize grip: two hairline ticks in `cue`.
    MouseArea {
        id: grip

        property real _startW: 0
        property real _startH: 0
        property point _start: Qt.point(0, 0)

        visible: root.editing && root.resizable
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 20
        height: 20
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true

        onPressed: mouse => {
            const p = mapToItem(root.area, mouse.x, mouse.y);
            grip._start = p;
            grip._startW = root.width;
            grip._startH = root.height;
            root._liveWidth = root.width;
            root._liveHeight = root.height;
            root._resizing = true;
        }
        onPositionChanged: mouse => {
            if (!root._resizing)
                return;
            const p = mapToItem(root.area, mouse.x, mouse.y);
            root._liveWidth = Math.min(root.area.width - root.x, Math.max(root.minWidth, root._snap(grip._startW + p.x - grip._start.x)));
            root._liveHeight = Math.min(root.area.height - root.y, Math.max(root.minHeight, root._snap(grip._startH + p.y - grip._start.y)));
        }
        onReleased: {
            root._persist(root.x, root.y, root._liveWidth, root._liveHeight);
            root._resizing = false;
        }

        Rectangle {
            x: parent.width - 12
            y: parent.height - 3
            width: 9
            height: 1
            color: Signal.palette.cue
        }

        Rectangle {
            x: parent.width - 3
            y: parent.height - 12
            width: 1
            height: 9
            color: Signal.palette.cue
        }

        Accessible.role: Accessible.Grip
        Accessible.name: qsTr("Resize %1").arg(root.entry.name || root.pluginId)
    }

    // Dimension readout while editing (Plex Mono, tabular).
    Rectangle {
        visible: root.editing
        x: 0
        y: -height - 8
        width: dims.implicitWidth + 12
        height: dims.implicitHeight + 4
        radius: Appearance.rounding.small
        color: Signal.palette.lifted
        border.width: 1
        border.color: Signal.palette.ruleStrong

        StyledText {
            id: dims

            anchors.centerIn: parent
            mono: true
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.ink
            text: `${Math.round(root.width)} × ${Math.round(root.height)}  ·  ${Math.round(root.x)}, ${Math.round(root.y)}`
        }
    }
}
