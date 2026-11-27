pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Workspace action bar — rename, new, close-all.
// Sits inside the preview card, no own background.
Item {
    id: root

    required property int wsId

    implicitWidth: parent ? parent.width : 400
    implicitHeight: layout.implicitHeight

    property bool renameActive: false

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right

        spacing: Appearance.spacing.small

        // Rename inline
        Item {
            visible: Compositor.capabilities.workspaceRename === true
            Layout.fillWidth: true
            Layout.preferredHeight: renameField.visible ? renameField.implicitHeight + Appearance.padding.small : renameBtn.implicitHeight
            clip: true

            TextButton {
                id: renameBtn
                anchors.left: parent.left
                visible: !root.renameActive
                type: TextButton.Tonal
                text: qsTr("Rename")
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.small / 2
                font.pointSize: Appearance.font.size.small

                onClicked: root.renameActive = true
            }

            RowLayout {
                anchors.fill: parent
                visible: root.renameActive
                spacing: Appearance.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: renameField.implicitHeight + Appearance.padding.small
                    radius: Appearance.rounding.small
                    color: Signal.tPalette.raised
                    border.width: 1
                    border.color: Signal.palette.signal

                    StyledTextField {
                        id: renameField
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Appearance.padding.small
                        placeholderText: qsTr("Workspace name…")
                        font.pointSize: Appearance.font.size.small

                        focus: root.renameActive
                        onAccepted: {
                            if (text.trim().length > 0)
                                Compositor.renameWorkspace(root.wsId, text.trim());
                            text = ""
                            root.renameActive = false
                        }
                        Keys.onEscapePressed: {
                            text = ""
                            root.renameActive = false
                        }
                    }
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "check"
                    accessibleName: qsTr("Confirm workspace rename")
                    padding: Appearance.padding.small / 2
                    font.pointSize: Appearance.font.size.small

                    onClicked: {
                        if (renameField.text.trim().length > 0)
                            Compositor.renameWorkspace(root.wsId, renameField.text.trim());
                        renameField.text = ""
                        root.renameActive = false
                    }
                }

                IconButton {
                    type: IconButton.Text
                    icon: "x"
                    accessibleName: qsTr("Cancel workspace rename")
                    padding: Appearance.padding.small / 2
                    font.pointSize: Appearance.font.size.small

                    onClicked: {
                        renameField.text = ""
                        root.renameActive = false
                    }
                }
            }
        }

        // New workspace
        TextButton {
            type: TextButton.Tonal
            text: qsTr("New WS")
            horizontalPadding: Appearance.padding.normal
            verticalPadding: Appearance.padding.small / 2
            font.pointSize: Appearance.font.size.small

            visible: Compositor.capabilities.workspaceCreate === true
            onClicked: Compositor.createEmptyWorkspace()
        }

        // Close all windows in this WS
        TextButton {
            type: TextButton.Tonal
            text: qsTr("Close All")
            horizontalPadding: Appearance.padding.normal
            verticalPadding: Appearance.padding.small / 2
            font.pointSize: Appearance.font.size.small

            onClicked: {
                const toplevels = Compositor.windowsForWorkspace(root.wsId);
                for (const t of toplevels)
                    Compositor.closeWindowFor(t);
            }
        }
    }
}
