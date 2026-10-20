pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Input (shell#226, first slice): keyboard layout
// state and switching through `horneroctl hardware keyboard`, plus
// the system keyboard settings GUI the CLI already owns. Pointer /
// touchpad tuning and the keybindings editor stay tracked in #226
// and #236 — nothing here fakes compositor ownership.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property string layoutText: qsTr("Reading keyboard layout…")
    property string actionText: ""

    function refresh(): void {
        layoutProc.out = "";
        layoutProc.command = ["horneroctl", "hardware", "keyboard", "layout", "--current", "--json"];
        layoutProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: layoutProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                layoutProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(layoutProc.out.trim());
                root.layoutText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.layoutText = qsTr("horneroctl keyboard unavailable on this system.");
            }
        }
    }

    Process {
        id: actionProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                actionProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(actionProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.actionText = "";
            }
            root.refresh();
        }
    }

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        radius: border.innerRadius
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
                    text: qsTr("Input")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Keyboard layout today; pointer, touchpad and the keybindings editor arrive in later slices of #226/#236.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: kbCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: kbCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Keyboard layout")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.layoutText
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Switch layout")
                                type: TextButton.Filled
                                onClicked: {
                                    actionProc.out = "";
                                    actionProc.command = ["horneroctl", "hardware", "keyboard", "layout", "--toggle", "--yes", "--json"];
                                    actionProc.running = true;
                                }
                            }

                            TextButton {
                                text: qsTr("Keyboard settings…")
                                type: TextButton.Tonal
                                onClicked: {
                                    actionProc.out = "";
                                    actionProc.command = ["horneroctl", "hardware", "keyboard", "settings", "--json"];
                                    actionProc.running = true;
                                }
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: root.refresh()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionText !== ""
                            text: root.actionText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }
}
