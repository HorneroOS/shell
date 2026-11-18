pragma ComponentBehavior: Bound

import Quickshell
import qs.components
import qs.services
import qs.config
import qs.modules.plugins
import QtQuick

// Bar island for extension indicators (shell#441): a structural copy of the
// system tray island (Tray.qml). Same chip and padding, the same Column/Row
// with scale-in add and animated move transitions, the same compact chevron
// whose expansion the bar drives (opens over the chevron, stays open while
// the pointer is in the island or its popout, closes on another entry), and
// the same expressive size animation. Configured like the tray
// (bar.extensions.background / compact / recolour / hiddenIcons).
StyledRect {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property ShellScreen screen
    readonly property alias layout: layout
    readonly property alias expandIcon: expandIcon
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Clear bars draw no chips, as for the tray.
    property bool clear: false
    property var fallbackSections: []
    // False when the owning layout renders no island here (Bar.qml uses
    // this island as the end-group fallback in layouts without an
    // "extensions" entry, gated to the end group).
    property bool surfaceActive: true
    // Responsive host context forwarded to the plugin hosts (#372).
    property string hostEdge: ""
    property bool hostCompact: false
    property int hostThickness: 0
    property string hostScreenName: ""

    readonly property bool chip: Config.bar.extensions.background && !clear
    // Overflow guard: many enabled indicators used to run over the bar's
    // other groups (18 text indicators overlapped the left group and the
    // clock). When the row would take more than its budget of the bar's main axis
    // it collapses behind the chevron exactly like bar.extensions.compact.
    // The budget is bar.extensions.islandBudget (default 40%). The island is
    // also the overflow sink of the other islands (shell#531).
    readonly property real crowdedLimit: (root.vertical ? root.screen.height : root.screen.width) * Config.bar.extensions.islandBudget / 100
    readonly property bool crowded: !Config.bar.extensions.compact && root.count > 1
        && (root.vertical ? layout.implicitHeight : layout.implicitWidth) + root.padding * 2 > root.crowdedLimit
    readonly property bool compact: Config.bar.extensions.compact || root.crowded
    readonly property int padding: root.chip ? Appearance.padding.normal : Appearance.padding.small
    readonly property int spacing: root.chip ? Appearance.spacing.small : 0
    readonly property int count: layout.item?.hostCount ?? 0

    // Driven by the bar exactly like Tray.expanded (Bar.closeTray resets it).
    property bool expanded

    readonly property real nonAnimHeight: {
        if (!root.compact)
            return layout.implicitHeight + root.padding * 2;
        return (root.expanded ? expandIcon.implicitHeight + layout.implicitHeight + root.spacing : expandIcon.implicitHeight) + root.padding * 2;
    }
    readonly property real nonAnimWidth: {
        if (!root.compact)
            return layout.implicitWidth + root.padding * 2;
        return (root.expanded ? expandIcon.implicitWidth + layout.implicitWidth + root.spacing : expandIcon.implicitWidth) + root.padding * 2;
    }

    // Island cross-axis size (Density.chip): the cell size, shrunk so the
    // island keeps its inset from the bar edge. Set by Bar.qml.
    property int cross: Density.inner

    clip: true
    visible: root.surfaceActive && root.count > 0 && (root.vertical ? height > 0 : width > 0)
    implicitWidth: root.vertical ? root.cross : root.nonAnimWidth
    implicitHeight: root.vertical ? root.nonAnimHeight : root.cross
    color: Qt.alpha(Signal.tPalette.panel, (root.chip && root.count > 0) ? Signal.tPalette.panel.a : 0)
    radius: Appearance.rounding.small

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Extensions")

    // Overflow sink (shell#531): while this island renders, other islands
    // of the same bar may hand it the indicators they cannot fit. Keyed per
    // bar ("<screen>|<edge>"), matching PluginBarWidgets.barKey.
    property string barEdge: root.hostEdge
    readonly property string sinkKey: `${root.hostScreenName !== "" ? root.hostScreenName : (root.screen?.name ?? "")}|${root.barEdge}`
    // null while not registered.
    property var registeredSink: null
    function syncSink(): void {
        const want = root.surfaceActive && root.screen ? root.sinkKey : null;
        if (want === root.registeredSink)
            return;
        if (root.registeredSink !== null)
            Plugins.setOverflowSink(root.registeredSink, false);
        root.registeredSink = want;
        if (want !== null)
            Plugins.setOverflowSink(want, true);
    }
    onSurfaceActiveChanged: root.syncSink()
    onSinkKeyChanged: root.syncSink()
    Component.onCompleted: root.syncSink()
    Component.onDestruction: {
        if (root.registeredSink !== null)
            Plugins.setOverflowSink(root.registeredSink, false);
    }

    Loader {
        id: layout

        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.top: root.vertical ? parent.top : undefined
        anchors.topMargin: root.padding
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.left: root.vertical ? undefined : parent.left
        anchors.leftMargin: root.padding

        opacity: root.expanded || !root.compact ? 1 : 0
        sourceComponent: root.vertical ? columnComp : rowComp

        Behavior on opacity {
            Anim {}
        }
    }

    Component {
        id: columnComp

        Column {
            readonly property int hostCount: items.count

            spacing: Appearance.spacing.small

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

            PluginBarWidgets {
                id: items

                vertical: root.vertical
                section: "end"
                acceptOverflow: true
                centerChildren: true
                surfaceActive: root.surfaceActive
                fallbackSections: root.fallbackSections
                hiddenIds: Config.bar.extensions.hiddenIcons
                // Recolour mirrors the tray: icons take the secondary tint;
                // without it the island leaves plugin icon colours alone.
                iconColour: Config.bar.extensions.recolour ? root.tone.ink : "transparent"
                iconSize: Density.iconPt
                textSize: Density.textPt
                edge: root.hostEdge
                barEdge: root.barEdge
                compact: root.hostCompact
                thickness: root.hostThickness > 0 ? root.hostThickness : Density.inner
                screenName: root.hostScreenName !== "" ? root.hostScreenName : root.screen.name
            }
        }
    }

    Component {
        id: rowComp

        Row {
            readonly property int hostCount: hItems.count

            spacing: Appearance.spacing.small

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

            PluginBarWidgets {
                id: hItems

                vertical: root.vertical
                section: "end"
                acceptOverflow: true
                centerChildren: true
                surfaceActive: root.surfaceActive
                fallbackSections: root.fallbackSections
                hiddenIds: Config.bar.extensions.hiddenIcons
                // Recolour mirrors the tray: icons take the secondary tint;
                // without it the island leaves plugin icon colours alone.
                iconColour: Config.bar.extensions.recolour ? root.tone.ink : "transparent"
                iconSize: Density.iconPt
                textSize: Density.textPt
                edge: root.hostEdge
                barEdge: root.barEdge
                compact: root.hostCompact
                thickness: root.hostThickness > 0 ? root.hostThickness : Density.inner
                screenName: root.hostScreenName !== "" ? root.hostScreenName : root.screen.name
            }
        }
    }

    Loader {
        id: expandIcon

        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.bottom: root.vertical ? parent.bottom : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.right: root.vertical ? undefined : parent.right

        active: root.compact && root.count > 0

        sourceComponent: Item {
            implicitWidth: root.vertical ? expandIconInner.implicitWidth : expandIconInner.implicitWidth - Appearance.padding.small * 2
            implicitHeight: root.vertical ? expandIconInner.implicitHeight - Appearance.padding.small * 2 : expandIconInner.implicitHeight

            Glyph {
                id: expandIconInner

                anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
                anchors.bottom: root.vertical ? parent.bottom : undefined
                anchors.bottomMargin: root.vertical ? (root.chip ? Appearance.padding.small : -Appearance.padding.small) : 0
                anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
                anchors.right: root.vertical ? undefined : parent.right
                anchors.rightMargin: root.vertical ? 0 : (root.chip ? Appearance.padding.small : -Appearance.padding.small)
                name: root.vertical ? "chevron-up" : "chevron-right"
                color: root.tone.ink
                font.pointSize: Density.iconPt
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    Anim {}
                }

                Behavior on anchors.bottomMargin {
                    Anim {}
                }

                Behavior on anchors.rightMargin {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.settle
            easing.bezierCurve: Appearance.anim.curves.settle
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.settle
            easing.bezierCurve: Appearance.anim.curves.settle
        }
    }
}
