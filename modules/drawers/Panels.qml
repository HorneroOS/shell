import qs.config
import qs.modules.osd as Osd
import qs.modules.notifications as Notifications
import qs.modules.session as Session
import qs.modules.launcher as Launcher
import qs.modules.dashboard as Dashboard
import qs.modules.layoutpicker as LayoutPicker
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities as Utilities
import qs.modules.utilities.toasts as Toasts
import qs.modules.sidebar as Sidebar
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property Item bar

    readonly property alias osd: osd
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popouts
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar
    readonly property alias layoutPicker: layoutPicker

    // Floating bars must keep real distance from panels/widgets/edges:
    // the wrapper only reserves pill thickness, so panels add a generous
    // breathing gap on the bar edge (spacing.large + the built-in margin).
    readonly property real floatBreathing: Appearance.spacing.large

    anchors.fill: parent
    anchors.leftMargin: bar.marginLeft + (bar.openOn("left") ? root.floatBreathing : 0)
    anchors.rightMargin: bar.marginRight + (bar.openOn("right") ? root.floatBreathing : 0)
    anchors.topMargin: bar.marginTop + (bar.openOn("top") ? root.floatBreathing : 0)
    anchors.bottomMargin: bar.marginBottom + (bar.openOn("bottom") ? root.floatBreathing : 0)

    Osd.Wrapper {
        id: osd
        objectName: "osd"

        clip: session.width > 0 || sidebar.width > 0
        screen: root.screen
        visibilities: root.visibilities

        // User placement along the edge (Config.osd.align), centred by default.
        readonly property string align: ["top", "bottom"].includes(Config.osd.align) ? Config.osd.align : "center"
        anchors.verticalCenter: align === "center" ? parent.verticalCenter : undefined
        anchors.top: align === "top" ? parent.top : undefined
        anchors.bottom: align === "bottom" ? parent.bottom : undefined
        anchors.topMargin: align === "top" ? Appearance.spacing.large : 0
        anchors.bottomMargin: align === "bottom" ? Appearance.spacing.large : 0
        anchors.right: parent.right
        anchors.rightMargin: session.width + sidebar.width
    }

    Notifications.Wrapper {
        id: notifications
        objectName: "notifications"

        visibilities: root.visibilities
        panels: root

        // User placement along the top edge (Config.notifs.align), right by
        // default. Only the popup stack moves: the notification centre
        // (sidebar) stays on the right edge.
        readonly property string align: ["left", "center"].includes(Config.notifs.align) ? Config.notifs.align : "right"
        anchors.top: parent.top
        anchors.right: align === "right" ? parent.right : undefined
        anchors.left: align === "left" ? parent.left : undefined
        anchors.horizontalCenter: align === "center" ? parent.horizontalCenter : undefined
    }

    Session.Wrapper {
        id: session
        objectName: "session"

        clip: sidebar.width > 0
        visibilities: root.visibilities
        panels: root

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sidebar.width
    }

    Launcher.Wrapper {
        id: launcher
        objectName: "launcher"

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        // User placement along the edge (Config.launcher.align), centred by default.
        readonly property string align: ["left", "right"].includes(Config.launcher.align) ? Config.launcher.align : "center"
        anchors.horizontalCenter: align === "center" ? parent.horizontalCenter : undefined
        anchors.left: align === "left" ? parent.left : undefined
        anchors.right: align === "right" ? parent.right : undefined
        anchors.leftMargin: align === "left" ? Appearance.spacing.large : 0
        anchors.rightMargin: align === "right" ? Appearance.spacing.large : 0
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard
        objectName: "dashboard"

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    // Bar popouts place themselves with the shared solver
    // (components/placement): this panel only tells the surface where the
    // screen and the bars are, in its own coordinates.
    BarPopouts.Wrapper {
        id: popouts
        objectName: "popouts"

        screen: root.screen
        // Attached popouts grow out of their bar (machined fillet). Keyed on
        // the owning bar's edge, which is known before placement: reading
        // the solved `edge` here made the fillet a dependent of
        // `placement` while it was being evaluated (binding loop on
        // "placement" at startup). An attached popout's anchor edge is
        // always its bar's edge, so the radius is the same.
        fillet: root.bar.filletOn(popouts.ownerEdge)
        filletRule: root.bar.filletRule(popouts.ownerEdge)
        bounds: Qt.rect(-root.x, -root.y, root.parent?.width ?? 0, root.parent?.height ?? 0)
        reserved: ({
                top: root.bar.marginTop,
                bottom: root.bar.marginBottom,
                left: root.bar.marginLeft,
                right: root.bar.marginRight
            })
    }

    Utilities.Wrapper {
        id: utilities
        objectName: "utilities"

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popouts

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Appearance.padding.normal
    }

    Sidebar.Wrapper {
        id: sidebar
        objectName: "sidebar"

        visibilities: root.visibilities
        panels: root

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
    }

    LayoutPicker.Wrapper {
        id: layoutPicker
        objectName: "layoutPicker"

        visibilities: root.visibilities
        panels: root

        anchors.centerIn: parent
    }
}
