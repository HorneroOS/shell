import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property string suffix: ""
    property bool readonly: false

    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        StyledText {
            visible: root.label !== ""
            text: root.label
            font.pointSize: Appearance.font.size.normal
            color: root.readonly ? Signal.palette.ruleStrong : Signal.palette.ink
        }

        Item {
            Layout.fillWidth: true
        }

        Glyph {
            visible: root.readonly
            name: "lock"
            color: Signal.palette.ruleStrong
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            text: Math.round(root.value) + (root.suffix !== "" ? " " + root.suffix : "")
            font.pointSize: Appearance.font.size.normal
            color: root.readonly ? Signal.palette.ruleStrong : Signal.palette.ink
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: Appearance.padding.normal
        radius: Appearance.rounding.small
        color: Signal.layer(Signal.palette.lifted, 1)
        opacity: root.readonly ? 0.5 : 1.0

        StyledRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * ((root.value - root.from) / (root.to - root.from))
            radius: parent.radius
            color: root.readonly ? Signal.palette.ruleStrong : Signal.palette.signal
        }
    }
}
