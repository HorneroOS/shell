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
    readonly property bool isActive: activeWsId === ws
    readonly property bool isUrgent: !isActive && (niriMode ? (workspaceData?.is_urgent ?? false) : (urgent[ws] ?? false))
    readonly property bool isVisibleElsewhere: !isActive && (visibleElsewhere[ws] ?? false)
    // The cell edge facing the desktop content, per owning bar edge.
    readonly property bool contentAtTop: edge === "bottom"
    readonly property bool contentAtLeft: edge === "right"
    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property string accessibleState: root.isActive ? qsTr("current") : root.isUrgent ? qsTr("urgent") : root.isVisibleElsewhere ? qsTr("visible on another monitor") : root.isOccupied ? qsTr("occupied") : qsTr("empty")
    // Unanimated prop for others to use as reference (main-axis size)
    readonly property int size: (vertical ? implicitHeight : implicitWidth) + (hasWindows ? Appearance.padding.small : 0)

    readonly property var ws: niriMode ? workspaceData?.id : groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows
    readonly property var windowItems: Compositor.windowsForWorkspace(ws)

    function iconForWindow(window: var): string {
        const appId = niriMode ? window.app_id : window.lastIpcObject.class;
        return Icons.getAppCategoryIcon(appId, "terminal");
    }

    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.preferredHeight: vertical ? size : implicitHeight
    Layout.preferredWidth: vertical ? implicitWidth : size
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    GridLayout {
        id: content

        anchors.fill: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: 0

        StyledText {
            id: indicator

            Layout.alignment: root.vertical ? Qt.AlignHCenter | Qt.AlignTop : Qt.AlignVCenter | Qt.AlignLeft
            Layout.preferredHeight: root.vertical ? Density.inner - Appearance.padding.small * 2 : implicitHeight
            Layout.preferredWidth: root.vertical ? implicitWidth : Density.inner - Appearance.padding.small * 2

            animate: true
            mono: true
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
            color: {
                // §5: urgent numeral in alert; active and visible-elsewhere
                // in ink; occupied and empty in inkMuted (the tick and the
                // edge marks carry the remaining distinction).
                if (root.isUrgent)
                    return root.tone.alert;
                if (root.labels)
                    return root.isActive ? root.tone.signal : root.isOccupied ? root.tone.ink : root.tone.inkMuted;
                return root.isActive || root.isVisibleElsewhere ? root.tone.ink : root.tone.inkMuted;
            }
            verticalAlignment: Qt.AlignVCenter
            horizontalAlignment: Qt.AlignHCenter
        }

        Loader {
            id: windows

            Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            Layout.fillHeight: root.vertical
            Layout.fillWidth: !root.vertical
            Layout.topMargin: root.vertical ? -Density.inner / 10 : 0
            Layout.leftMargin: root.vertical ? 0 : -Density.inner / 10

            visible: active
            active: root.hasWindows

            sourceComponent: root.vertical ? vIconsComp : hIconsComp
        }

        Component {
            id: vIconsComp

            Column {
                spacing: 0

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
                        values: root.windowItems.slice(0, Config.bar.workspaces.maxWindowIcons)
                    }

                    Glyph {
                        size: Density.iconPt
                        required property var modelData

                        name: root.iconForWindow(modelData)
                        color: root.tone.inkMuted
                    }
                }
            }
        }

        Component {
            id: hIconsComp

            Row {
                spacing: 0

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
                    values: root.windowItems.slice(0, Config.bar.workspaces.maxWindowIcons)
                    }

                    Glyph {
                        size: Density.iconPt
                        required property var modelData

                        name: root.iconForWindow(modelData)
                        color: root.tone.inkMuted
                    }
                }
            }
        }
    }

    // §5 occupancy tick: 4 × 2 px, 4 px from the edge away from the
    // content. Alert-coloured while urgent.
    Rectangle {
        visible: root.isOccupied && !root.isActive
        width: root.vertical ? 2 : 4
        height: root.vertical ? 4 : 2
        x: root.vertical ? (root.contentAtLeft ? root.width - width - 4 : 4) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (root.contentAtTop ? root.height - height - 4 : 4)
        color: root.isUrgent ? root.tone.alert : root.tone.inkMuted

        Behavior on color {
            CAnim {}
        }
    }

    // §5 visible on another monitor: 1 px ruleStrong outline on the
    // content-facing edge, no fill.
    Rectangle {
        visible: root.isVisibleElsewhere
        width: root.vertical ? 1 : root.width
        height: root.vertical ? root.height : 1
        x: root.vertical ? (root.contentAtLeft ? 0 : root.width - 1) : 0
        y: root.vertical ? 0 : (root.contentAtTop ? 0 : root.height - 1)
        color: root.tone.active ? root.tone.inkMuted : Signal.palette.ruleStrong
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
