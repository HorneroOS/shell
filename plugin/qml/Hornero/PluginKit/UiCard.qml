import QtQuick

Rectangle {
    id: root

    // Inside a dashboard card the host already draws the surface and its
    // padding; a second surface and inset would double the frame.
    readonly property bool hostedOnDashboard: {
        let p = root.parent;
        while (p) {
            if ("hostSurface" in p)
                return p.hostSurface === "dashboard";
            p = p.parent;
        }
        return false;
    }
    property int padding: hostedOnDashboard ? 0 : Theme.spacing
    default property alias content: container.data

    color: hostedOnDashboard ? "transparent" : Theme.surfaceContainer
    radius: Theme.rounding
    implicitWidth: container.implicitWidth + root.padding * 2
    implicitHeight: container.implicitHeight + root.padding * 2

    Item {
        id: container

        anchors.fill: parent
        anchors.margins: root.padding
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
