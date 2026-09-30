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

    // Take focus while open so window-level Escape reaches the
    // central cascade (S4 will move this to focusable controls).
    // Deferred to visibility: focusing while still hidden fails.
    focus: true
    onVisibleChanged: {
        if (visible && root.visibilities.utilities)
            root.forceActiveFocus();
    }

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
