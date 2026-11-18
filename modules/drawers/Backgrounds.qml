import qs.components
import qs.services
import qs.config
import qs.modules.osd as Osd
import qs.modules.notifications as Notifications
import qs.modules.session as Session
import qs.modules.launcher as Launcher
import qs.modules.dashboard as Dashboard
import qs.modules.utilities as Utilities
import qs.modules.sidebar as Sidebar
import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    required property Panels panels
    required property Item bar

    // Same coordinate space as Panels (including the breathing gap next to
    // floating/clear bars): every background is drawn at its wrapper's
    // panel coordinates, so any offset here misplaces all panel shapes.
    anchors.fill: parent
    anchors.leftMargin: panels.anchors.leftMargin
    anchors.rightMargin: panels.anchors.rightMargin
    anchors.topMargin: panels.anchors.topMargin
    anchors.bottomMargin: panels.anchors.bottomMargin
    preferredRendererType: Shape.CurveRenderer

    Osd.Background {
        wrapper: root.panels.osd
        // Only against the frame: next to an open session or sidebar the
        // neighbour's own outline would cross the fillet.
        fillet: root.panels.session.width > 0 || root.panels.sidebar.width > 0 ? 0 : root.bar.filletOn("right")
        rule: root.bar.filletRule("right")

        startX: root.width - root.panels.session.width - root.panels.sidebar.width
        startY: (root.height - wrapper.height) / 2 - rounding
    }

    Notifications.Background {
        wrapper: root.panels.notifications
        sidebar: sidebar

        startX: root.width
        startY: 0
    }

    Session.Background {
        wrapper: root.panels.session
        fillet: root.panels.sidebar.width > 0 ? 0 : root.bar.filletOn("right")
        rule: root.bar.filletRule("right")

        startX: root.width - root.panels.sidebar.width
        startY: (root.height - wrapper.height) / 2 - rounding
    }

    Launcher.Background {
        wrapper: root.panels.launcher
        fillet: root.bar.filletOn("bottom")
        rule: root.bar.filletRule("bottom")

        // Track the wrapper's outer edge: identical to the panel edge when the
        // bar is attached, but stops at the wrapper when the bar floats
        // (otherwise the connection "wings" dangle next to the floating pill)
        startX: (root.width - wrapper.width) / 2 - rounding
        startY: wrapper.y + wrapper.height
    }

    Dashboard.Background {
        wrapper: root.panels.dashboard
        fillet: root.bar.filletOn("top")
        rule: root.bar.filletRule("top")

        startX: (root.width - wrapper.width) / 2 - rounding
        startY: wrapper.y
    }

    Utilities.Background {
        wrapper: root.panels.utilities
        sidebar: sidebar
        fillet: root.bar.filletOn("bottom")
        rule: root.bar.filletRule("bottom")
        // The right-edge junction is shared with the sidebar while it is open.
        filletEnd: root.panels.sidebar.width > 0 ? 0 : root.bar.filletOn("right")
        ruleEnd: root.bar.filletRule("right")

        startX: root.width
        startY: wrapper.y + wrapper.height
    }

    Sidebar.Background {
        id: sidebar

        wrapper: root.panels.sidebar
        panels: root.panels
        fillet: root.bar.filletOn("right")
        rule: root.bar.filletRule("right")

        startX: root.width
        startY: root.panels.notifications.height
    }
}
