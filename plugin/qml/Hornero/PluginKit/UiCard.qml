import QtQuick

// Signal instrument module (visual language §7.1): `panel` fill, 1 px
// `rule` border, radius 3, eyebrow header with an optional channel
// number on the left and a context eyebrow on the right:
//
//   UiCard { channel: 2; title: "Telemetry"; context: "60 s window" }
//
// While keyboard focus is inside the card a 2 × 10 px `signal`
// registration tick marks its leading top corner. Inside a dashboard
// card or a desktop widget frame the host already draws the module, so
// the card draws only its header and content.
Rectangle {
    id: root

    readonly property bool hostFramed: {
        let p = root.parent;
        while (p) {
            if ("hostSurface" in p)
                return p.hostSurface === "dashboard" || p.hostSurface === "desktop";
            p = p.parent;
        }
        return false;
    }
    property int padding: hostFramed ? 0 : Theme.padding.larger
    default property alias content: container.data

    property string title: ""
    property int channel: 0
    property string context: ""
    property string glyph: ""
    readonly property bool hasHeader: root.title.length > 0 || root.glyph.length > 0

    readonly property bool focusInside: {
        let item = root.Window.activeFocusItem;
        while (item) {
            if (item === root)
                return true;
            item = item.parent;
        }
        return false;
    }

    color: hostFramed ? "transparent" : Theme.palette.panel
    radius: Theme.rounding.small
    border.width: hostFramed ? 0 : 1
    border.color: Theme.palette.rule
    implicitWidth: Math.max(header.implicitWidth, container.implicitWidth) + root.padding * 2
    implicitHeight: (root.hasHeader ? header.implicitHeight + Theme.spacing.smaller : 0) + container.implicitHeight + root.padding * 2

    Row {
        id: header

        visible: root.hasHeader
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: Theme.spacing.smaller

        UiIcon {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: Theme.font.size.normal
            color: Theme.palette.inkMuted
        }

        UiEyebrow {
            anchors.verticalCenter: parent.verticalCenter
            width: header.width - (root.glyph.length > 0 ? Theme.font.size.normal + Theme.spacing.smaller + 4 : 0)
            text: root.title
            channel: root.channel
            context: root.context
        }
    }

    Item {
        id: container

        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.padding + (root.hasHeader ? header.implicitHeight + Theme.spacing.smaller : 0)
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    // Registration tick (RFC §2): the focused module, not a glow.
    Rectangle {
        visible: root.focusInside && !root.hostFramed
        x: 0
        y: 0
        width: 2
        height: 10
        color: Theme.palette.signal
    }
}
