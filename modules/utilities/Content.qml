import "cards"
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var props
    required property var visibilities
    required property Item popouts

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Focusable root for S4 keyboard navigation. Escape delivery
    // comes from the HyprlandFocusGrab, not Qt item focus (INTERACTION.md).
    focus: true

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        IdleInhibit {}

        Record {
            props: root.props
            visibilities: root.visibilities
            z: 1
        }

        Toggles {
            visibilities: root.visibilities
            popouts: root.popouts
        }
    }

    RecordingDeleteModal {
        props: root.props
    }
}
