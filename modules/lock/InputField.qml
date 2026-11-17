pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Password entry: one square segment per typed character (never the
// characters themselves), a placeholder when empty. No per-character
// animation; the field is a readout, not a toy.
Item {
    id: root

    required property Pam pam
    readonly property alias placeholder: placeholder
    property string buffer

    Accessible.role: Accessible.EditableText
    Accessible.name: qsTr("Password")
    Accessible.description: qsTr("Type your password, then press Enter to unlock")

    Layout.fillWidth: true
    Layout.fillHeight: true

    clip: true

    Connections {
        target: root.pam

        function onBufferChanged(): void {
            root.buffer = root.pam.buffer;
        }
    }

    StyledText {
        id: placeholder

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Appearance.padding.small

        text: {
            if (root.pam.passwd.active)
                return qsTr("Checking…");
            if (root.pam.state === "max")
                return qsTr("Too many attempts");
            return qsTr("Enter your password");
        }

        mono: true
        elide: Text.ElideRight
        color: root.pam.passwd.active ? Signal.palette.cue : Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.normal

        visible: !root.buffer
    }

    Row {
        id: chars

        // Keep the newest characters in view when the buffer outgrows the field.
        readonly property real fullWidth: root.buffer.length * (8 + 3) - 3

        anchors.verticalCenter: parent.verticalCenter
        x: Appearance.padding.small + Math.min(0, root.width - Appearance.padding.small * 2 - fullWidth)
        spacing: 3

        Repeater {
            model: root.buffer.length

            Rectangle {
                width: 8
                height: 14
                radius: 1
                color: Signal.palette.ink
            }
        }
    }
}
