pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Window list panel — sits inside an instrument Frame, which owns the
// header and background.
Item {
    id: root

    required property int wsId
    required property var workspace

    readonly property var wsToplevels: Compositor.windowsForWorkspace(root.wsId)

    implicitWidth: parent ? parent.width : 300
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent

        spacing: Appearance.spacing.normal

        // Window list or empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.wsToplevels.length === 0
                spacing: Appearance.spacing.small

                Glyph {
                    Layout.alignment: Qt.AlignHCenter
                    name: "app-window"
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No windows")
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                }
            }

            // Window list
            StyledListView {
                id: winList

                anchors.fill: parent
                visible: root.wsToplevels.length > 0

                spacing: Appearance.spacing.small / 2
                clip: true

                model: ScriptModel {
                    values: root.wsToplevels
                }

                delegate: WindowListItem {
                    width: winList.width
                    isActive: Compositor.isNiri ? modelData.is_focused : modelData.wayland?.activated ?? false

                    onFocusRequested: {
                        Compositor.focusWindowFor(modelData);
                    }
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: winList
                }
            }
        }
    }
}
