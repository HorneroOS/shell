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

    // Optional native card header (icon + title), as on the shell's own
    // dashboard cards. Leave both empty to draw no header.
    property string title: ""
    property string icon: ""
    readonly property bool hasHeader: root.title.length > 0 || root.icon.length > 0
    readonly property int headerGap: root.hasHeader ? Theme.spacing : 0

    color: hostedOnDashboard ? "transparent" : Theme.surfaceContainer
    radius: Theme.rounding
    implicitWidth: Math.max(header.implicitWidth, container.implicitWidth) + root.padding * 2
    implicitHeight: header.height + root.headerGap + container.implicitHeight + root.padding * 2

    Row {
        id: header

        visible: root.hasHeader
        height: visible ? implicitHeight : 0
        x: root.padding
        y: root.padding
        spacing: Theme.spacingSmall

        UiIcon {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            color: Theme.primary
        }

        UiText {
            visible: root.title.length > 0
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            text: root.title
            Accessible.role: Accessible.Heading
        }
    }

    Item {
        id: container

        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.padding + header.height + root.headerGap
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
