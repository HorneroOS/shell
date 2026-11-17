pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Channel panel (signal-visual-language §4, §7): an eyebrow title with an
// optional real-value readout on the right, over a 1 px `rule` frame that
// holds hairline-separated SettingRow / DeviceRow / StreamLevel rows. It
// replaces the raised "tonal card": the frame has no fill, so grouping is
// carried by the eyebrow, the rule and the rows, never by a lifted surface.
// `readout` shows only a value the caller read from a service; pass
// `readoutAvailable: false` (or leave it empty) and it prints "unavailable".
ColumnLayout {
    id: root

    property string title: ""
    property string readout: ""
    property bool readoutAvailable: true
    property color readoutColor: Signal.palette.ink
    default property alias content: body.data
    // Lets kit rows detect that they sit inside a panel and drop their own frame.
    readonly property bool isChannelPanel: true

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        Accessible.role: Accessible.Heading
        Accessible.name: root.title

        Eyebrow {
            label: root.title
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: root.readout.length > 0 || !root.readoutAvailable
            mono: true
            text: root.readoutAvailable ? root.readout : qsTr("unavailable")
            color: root.readoutAvailable ? root.readoutColor : Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
            Accessible.ignored: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 2
        color: "transparent"
        border.width: 1
        border.color: Signal.palette.rule
        radius: Appearance.rounding.small

        ColumnLayout {
            id: body

            anchors.fill: parent
            anchors.margins: 1
            spacing: 0
        }
    }
}
