import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Props props
    required property var visibilities

    // Focusable root for S4 keyboard navigation. Escape delivery
    // comes from the HyprlandFocusGrab, not Qt item focus (INTERACTION.md).
    focus: true

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Appearance.rounding.small
            color: Signal.palette.sunken
            border.width: 1
            border.color: Signal.palette.rule

            NotifDock {
                props: root.props
                visibilities: root.visibilities
            }
        }

    }
}
