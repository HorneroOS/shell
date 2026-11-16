pragma ComponentBehavior: Bound

import Quickshell
import qs.components
import qs.services
import qs.config
import qs.modules.plugins
import QtQuick
import QtQuick.Layouts

// Bar island for extension indicators (shell#441): the same chip, spacing,
// appear/move transitions and compact behaviour as the system tray island,
// configurable the same way (bar.extensions.background / .compact). Holds
// every bar extension without a native section, plus those whose native
// island is absent from this layout.
StyledRect {
    id: root

    required property ShellScreen screen
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Clear bars draw no chips, as for the tray.
    property bool clear: false
    property var fallbackSections: []
    // False when the owning layout renders no island here (Bar.qml uses
    // this island as the end-group fallback in layouts without an
    // "extensions" entry, gated to the end group).
    property bool surfaceActive: true
    // Responsive host context forwarded to the plugin hosts (#372), set
    // by Bar.qml's fallback instance; the layout-entry instance leaves
    // the defaults, which reproduce the historic island context.
    property string hostEdge: ""
    property bool hostCompact: false
    property int hostThickness: 0
    property string hostScreenName: ""

    readonly property bool chip: Config.bar.extensions.background && !clear
    readonly property bool compact: Config.bar.extensions.compact
    readonly property int padding: root.chip ? Appearance.padding.normal : Appearance.padding.small
    readonly property int count: hosts.count
    // Compact islands collapse to a chevron and open while hovered, like
    // the compact tray.
    readonly property bool expanded: !root.compact || hover.hovered

    readonly property real contentMain: root.vertical ? grid.implicitHeight : grid.implicitWidth
    readonly property real chevronMain: root.compact ? (root.vertical ? chevron.implicitHeight : chevron.implicitWidth) : 0

    visible: root.surfaceActive && root.count > 0
    clip: true
    implicitWidth: root.vertical ? Config.bar.sizes.innerWidth : (root.expanded ? grid.implicitWidth : 0) + root.chevronMain + root.padding * 2
    implicitHeight: root.vertical ? (root.expanded ? grid.implicitHeight : 0) + root.chevronMain + root.padding * 2 : Config.bar.sizes.innerWidth
    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, root.chip && root.count > 0 ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Extensions")

    HoverHandler {
        id: hover
    }

    GridLayout {
        id: grid

        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.top: root.vertical ? parent.top : undefined
        anchors.left: root.vertical ? undefined : parent.left
        anchors.topMargin: root.vertical ? root.padding : 0
        anchors.leftMargin: root.vertical ? 0 : root.padding

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: Appearance.spacing.small
        columnSpacing: Appearance.spacing.small
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            Anim {}
        }

        PluginBarWidgets {
            id: hosts

            vertical: root.vertical
            section: "end"
            surfaceActive: root.surfaceActive
            fallbackSections: root.fallbackSections
            hiddenIds: Config.bar.extensions.hiddenIcons
            // Recolour mirrors the tray: icons take the secondary tint;
            // without it the island leaves plugin icon colours alone.
            iconColour: Config.bar.extensions.recolour ? Colours.palette.m3secondary : "transparent"
            iconSize: Appearance.font.size.larger
            textSize: Appearance.font.size.smaller
            edge: root.hostEdge
            compact: root.hostCompact
            thickness: root.hostThickness > 0 ? root.hostThickness : Config.bar.sizes.innerWidth
            screenName: root.hostScreenName !== "" ? root.hostScreenName : root.screen.name
        }
    }

    MaterialIcon {
        id: chevron

        visible: root.compact
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.bottom: root.vertical ? parent.bottom : undefined
        anchors.bottomMargin: root.vertical ? root.padding : 0
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.right: root.vertical ? undefined : parent.right
        anchors.rightMargin: root.vertical ? 0 : root.padding
        text: root.vertical ? "expand_less" : "chevron_right"
        font.pointSize: Appearance.font.size.large
        color: Colours.palette.m3onSurfaceVariant
        rotation: root.expanded ? 180 : 0

        Behavior on rotation {
            Anim {}
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }
}
