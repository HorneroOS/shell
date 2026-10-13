pragma ComponentBehavior: Bound

import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    property list<string> terminals: []
    property string selectedTerminal: "kitty"
    property string statusMessage: ""
    property bool loading: true
    property bool busy: false
    property bool listAnswered: false
    property bool actionAnswered: false
    property bool actionSucceeded: false

    function envelope(raw: string): var {
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    function refresh(): void {
        if (listProc.running || actionProc.running)
            return;
        root.loading = true;
        root.listAnswered = false;
        listProc.running = true;
    }

    function applyTerminal(id: string): void {
        if (root.busy || id === root.selectedTerminal)
            return;
        root.statusMessage = "";
        root.actionAnswered = false;
        root.actionSucceeded = false;
        root.busy = true;
        actionProc.command = ["horneroctl", "--json", "config", "default-apps", "set", "terminal", id, "--yes"];
        actionProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: listProc

        command: ["horneroctl", "--json", "config", "default-apps", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const response = root.envelope(text);
                root.listAnswered = response !== null;
                root.loading = false;
                if (!response || response.ok !== true) {
                    root.terminals = [];
                    root.statusMessage = response && response.message ? response.message : qsTr("Could not read terminal settings.");
                    return;
                }
                const data = response.data || {};
                root.selectedTerminal = String(data.terminal_shell_id || "kitty");
                root.terminals = String(data.terminals_available || "").split(",").filter(id => id.length > 0);
                root.statusMessage = root.terminals.length === 0 ? qsTr("Install Kitty, Alacritty, or Ghostty to choose a terminal.") : "";
            }
        }
        onExited: (exitCode, exitStatus) => {
            if ((exitCode !== 0 || exitStatus !== 0) && !root.listAnswered) {
                root.loading = false;
                root.statusMessage = qsTr("Terminal settings could not be loaded (exit %1).").arg(exitCode);
            }
        }
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            onStreamFinished: {
                const response = root.envelope(text);
                root.actionAnswered = response !== null;
                root.actionSucceeded = response !== null && response.ok === true;
                root.statusMessage = response && response.message ? response.message : "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0 && root.statusMessage.length === 0)
                    root.statusMessage = text.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if ((exitCode !== 0 || exitStatus !== 0) && !root.actionAnswered) {
                root.actionSucceeded = false;
                root.statusMessage = qsTr("The terminal setting could not be changed (exit %1).").arg(exitCode);
            }
            if (root.actionSucceeded)
                Qt.callLater(() => root.refresh());
        }
    }

    StyledClippingRect {
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

                SettingsHeader {
                    icon: "terminal"
                    title: qsTr("Terminal")
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Choose the terminal Hornero opens for shortcuts and integrated actions. The selection is shared with Exo, XDG terminal preferences, and Hornero Shell.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        visible: !root.loading && root.terminals.indexOf(root.selectedTerminal) < 0
                        Layout.fillWidth: true
                        text: qsTr("The saved default (%1) is not currently installed. Install it or choose an available terminal below.").arg(root.selectedTerminal)
                        color: Colours.palette.m3tertiary
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: root.terminals

                        delegate: StyledRect {
                            id: terminalCard

                            required property string modelData

                            Layout.fillWidth: true
                            implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
                            radius: Appearance.rounding.normal
                            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                            RowLayout {
                                id: row

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.normal
                                spacing: Appearance.spacing.normal

                                MaterialIcon {
                                    text: "terminal"
                                    color: terminalCard.modelData === root.selectedTerminal ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.large
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        text: terminalCard.modelData === "kitty" ? "Kitty" : terminalCard.modelData === "alacritty" ? "Alacritty" : "Ghostty"
                                        font.pointSize: Appearance.font.size.normal
                                        font.weight: 600
                                    }

                                    StyledText {
                                        text: terminalCard.modelData === root.selectedTerminal ? qsTr("Selected default") : qsTr("Installed and ready to use")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.smaller
                                    }
                                }

                                TextButton {
                                    text: terminalCard.modelData === root.selectedTerminal ? qsTr("Selected") : qsTr("Use this")
                                    type: terminalCard.modelData === root.selectedTerminal ? TextButton.Tonal : TextButton.Text
                                    enabled: !root.busy && terminalCard.modelData !== root.selectedTerminal
                                    Accessible.role: Accessible.Button
                                    Accessible.name: qsTr("Use %1 as the default terminal").arg(terminalCard.modelData)
                                    onClicked: root.applyTerminal(terminalCard.modelData)
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: root.loading
                        Layout.fillWidth: true
                        text: qsTr("Checking installed terminals…")
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        visible: root.statusMessage.length > 0
                        Layout.fillWidth: true
                        text: root.statusMessage
                        color: root.actionSucceeded ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                        Accessible.role: Accessible.StaticText
                        Accessible.name: root.statusMessage
                    }

                    TextButton {
                        visible: root.terminals.length === 0 && !root.loading
                        text: qsTr("Refresh")
                        type: TextButton.Tonal
                        enabled: !root.loading
                        onClicked: root.refresh()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Hornero keeps the terminal shortcut, XDG preference, Exo handler, and Shell app launches aligned. Install an alternative first, then return here to select it.")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.smaller
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
