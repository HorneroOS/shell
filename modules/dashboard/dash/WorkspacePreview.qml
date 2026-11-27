pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Live preview of the focused window in a workspace.
// Uses ScreencopyView — same pattern as WindowInfo/Preview.qml.
Item {
    id: root

    required property int wsId

    readonly property var wsToplevels: Compositor.windowsForWorkspace(root.wsId)
    readonly property var focusedToplevel: {
        return root.wsToplevels.find(t => t.wayland?.activated) ?? root.wsToplevels[0] ?? null;
    }

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Config.dashboard.workspaces.previewHeight

    StyledClippingRect {
        id: preview

        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Signal.tPalette.raised

        ScreencopyView {
            id: view

            anchors.centerIn: parent

            captureSource: root.focusedToplevel?.wayland ?? null
            live: true

            constraintSize.width: root.focusedToplevel
                ? parent.height * Math.min(
                    Screen.width / Screen.height,
                    (root.focusedToplevel?.lastIpcObject?.size?.[0] ?? 1) / (root.focusedToplevel?.lastIpcObject?.size?.[1] ?? 1)
                )
                : parent.width
            constraintSize.height: parent.height
        }

        // Empty state
        Item {
            anchors.fill: parent
            visible: root.focusedToplevel === null

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                Glyph {
                    Layout.alignment: Qt.AlignHCenter
                    name: "photo-off"
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.extraLarge * 2
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No windows to preview")
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.normal
                }
            }
        }
    }
}
