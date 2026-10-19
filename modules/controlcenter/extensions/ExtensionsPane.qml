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
import Quickshell.Io

// Control Center › Extensions: community plugin lifecycle.
// horneroctl stays the single writer of plugin lifecycle state: this
// pane never writes receipts or payloads itself, it only invokes
// `horneroctl plugin enable|disable <id> --yes` — the exact CLI
// commands — and re-reads state through the Plugins service. Enable
// (the direction that runs third-party QML as your user) requires an
// explicit inline confirmation, mirroring the CLI --yes gate.
// Install and remove stay CLI-only.
Item {
    id: root

    required property Session session

    property string pendingEnable: ""
    property string actionError: ""
    property var actionEnvelope: null

    function runLifecycle(action, pluginId) {
        root.actionError = "";
        root.actionEnvelope = null;
        lifecycleProc.command = ["horneroctl", "--json", "plugin", action, pluginId, "--yes"];
        lifecycleProc.running = true;
    }

    Process {
        id: lifecycleProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.actionEnvelope = JSON.parse(text);
                } catch (e) {
                    root.actionEnvelope = null;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const env = root.actionEnvelope;
            if (env && env.ok === true) {
                root.pendingEnable = "";
                root.actionError = "";
                Plugins.reload();
            } else {
                root.actionError = (env && env.message) ? String(env.message) : qsTr("Plugin action failed (exit %1).").arg(exitCode);
            }
        }
    }

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
                    text: qsTr("Community plugins run with your user's permissions — they are not sandboxed. Only enable plugins whose source you have reviewed. Enabling asks for confirmation here; install and remove stay in the CLI: horneroctl plugin install / remove")
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
                    visible: root.actionError.length > 0
                    text: root.actionError
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3error
                    wrapMode: Text.Wrap
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

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.pendingEnable === row.modelData.id
                                text: qsTr("This plugin's QML will run as your user, without a sandbox. Enable only if you reviewed its source.")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    visible: !row.modelData.enabled && root.pendingEnable !== row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Enable…")
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.actionError = "";
                                        root.pendingEnable = row.modelData.id;
                                    }
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Confirm enable")
                                    type: TextButton.Filled
                                    onClicked: root.runLifecycle("enable", row.modelData.id)
                                }

                                TextButton {
                                    visible: root.pendingEnable === row.modelData.id
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Cancel")
                                    type: TextButton.Text
                                    onClicked: root.pendingEnable = ""
                                }

                                TextButton {
                                    visible: row.modelData.enabled
                                    enabled: !lifecycleProc.running
                                    text: qsTr("Disable")
                                    type: TextButton.Tonal
                                    onClicked: root.runLifecycle("disable", row.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
