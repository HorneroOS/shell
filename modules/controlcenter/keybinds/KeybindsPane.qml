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

// Control Center › Keybinds (shell#236, read-only slice): the
// session's keybindings through `horneroctl hardware keyboard keys`
// (hyprlang or Lua provider, hornero#176), with local search.
// Rebinding stays in #236 — this pane never edits compositor config;
// the CLI is asked for data only (HORNERO_BYPASS_QUICKSHELL=1 stops
// its open-Settings shortcut from recursing into this very pane).
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property var binds: []
    property string query: ""
    property string statusText: qsTr("Reading keybindings…")

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return binds;
        return binds.filter(l => l.toLowerCase().includes(q));
    }

    function refresh(): void {
        keysProc.out = "";
        keysProc.command = ["env", "HORNERO_BYPASS_QUICKSHELL=1", "horneroctl", "hardware", "keyboard", "keys", "--json"];
        keysProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: keysProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                keysProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(keysProc.out.trim());
                root.binds = payload.ok ? (payload.message ?? "").toString().split("\n").filter(l => l.trim() !== "") : [];
                root.statusText = payload.ok ? qsTr("%1 keybindings · from %2").arg(root.binds.length).arg((payload.data ?? {}).file ?? "") : payload.message.toString();
            } catch (e) {
                root.binds = [];
                root.statusText = qsTr("horneroctl keyboard keys unavailable on this system.");
            }
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
                    text: qsTr("Keybinds")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledTextField {
                                Layout.fillWidth: true
                                placeholderText: qsTr("Search keybindings…")
                                onTextChanged: root.query = text
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: root.refresh()
                            }
                        }

                        Repeater {
                            model: root.shown

                            delegate: StyledText {
                                required property string modelData

                                Layout.fillWidth: true
                                text: modelData
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.shown.length === 0
                            text: qsTr("No keybindings match.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Read-only for now: rebinding Hornero actions lands in a later slice of #236 — this list always shows what the session actually runs.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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
