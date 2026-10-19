pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Control Center › Extensions: read-only view of community plugins.
// horneroctl is the single writer of plugin lifecycle state
// (install/enable/disable/remove), so this pane never mutates
// receipts or payloads: it shows what the Plugins service discovered,
// each plugin's load state, and offers re-discovery (reload). Enable
// and disable stay explicit CLI actions until a GUI lifecycle with
// the same consent gates exists.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.normal

                StyledText {
                    text: qsTr("Extensions")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Community plugins run with your user's permissions — they are not sandboxed. Only enable plugins whose source you have reviewed. Manage them with: horneroctl plugin list / enable / disable")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                TextButton {
                    text: qsTr("Reload plugin list")
                    type: TextButton.Tonal
                    onClicked: Plugins.reload()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Plugins.discovered && Plugins.entries.length === 0
                    text: qsTr("No community plugins installed. Install one with: horneroctl plugin install <path>")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: Plugins.entries

                    delegate: StyledRect {
                        id: row

                        required property var modelData

                        Layout.fillWidth: true
                        radius: Appearance.rounding.normal
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                        implicitHeight: rowCol.implicitHeight + Appearance.padding.large * 2

                        ColumnLayout {
                            id: rowCol

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: `${row.modelData.name} ${row.modelData.version}`
                                font.weight: 500
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.enabled ? qsTr("Enabled — state: %1").arg(row.modelData.state) : qsTr("Disabled")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!row.modelData.detail
                                text: row.modelData.detail ?? ""
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
