import qs.components
import qs.services
import qs.config
import QtQuick

// Instrument module frame (Signal Bezel §7.1): `panel` fill, 1 px `rule`
// border, radius `small`; optional header eyebrow + context and the
// registration tick when `active`.
StyledRect {
    id: root

    property string channel: ""
    property string title: ""
    property string context: ""
    property bool active: false
    property color contextColor: Signal.palette.inkMuted
    readonly property real headerHeight: title !== "" ? header.implicitHeight + Appearance.spacing.normal + Appearance.spacing.smaller : 0
    default property alias content: body.data
    property alias body: body
    // Surface inset (rack rhythm 16), scaled with Appearance > Scales.
    property int padding: Appearance.padding.large

    color: Signal.palette.panel
    radius: Appearance.rounding.small
    border.width: 1
    border.color: Signal.palette.rule

    RegistrationTick {
        visible: root.active
        x: 0
        y: 0
    }

    Item {
        id: header

        visible: root.title !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Appearance.spacing.normal
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        implicitHeight: eyebrow.implicitHeight

        Eyebrow {
            id: eyebrow

            anchors.left: parent.left
            anchors.right: ctx.left
            anchors.rightMargin: Appearance.spacing.smaller
            channel: root.channel
            label: root.title
        }

        Eyebrow {
            id: ctx

            anchors.right: parent.right
            label: root.context
            color: root.contextColor
        }
    }

    Item {
        id: body

        anchors.fill: parent
        anchors.topMargin: root.title !== "" ? root.headerHeight : root.padding
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding
    }
}
