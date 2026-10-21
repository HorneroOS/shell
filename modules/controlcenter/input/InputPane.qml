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

// Control Center › Input (shell#226): keyboard layout state and
// switching through `horneroctl hardware keyboard`, plus pointer /
// keyboard tuning through `horneroctl hypr input` (Hyprland live
// values, persisted by the CLI). On other compositors the pointer
// section reports the backend's unavailable state instead of
// faking controls. The keybindings editor stays in #236.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property string layoutText: qsTr("Reading keyboard layout…")
    property string actionText: ""
    property real sensitivity: 0
    property string accelProfile: "flat"
    property int repeatRate: 50
    property int repeatDelay: 300
    property bool naturalScroll: true
    property bool tapToClick: true
    property string compositor: ""

    function refresh(): void {
        layoutProc.out = "";
        layoutProc.command = ["horneroctl", "hardware", "keyboard", "layout", "--current", "--json"];
        layoutProc.running = true;
        inputProc.out = "";
        inputProc.command = ["horneroctl", "hypr", "input", "status", "--json"];
        inputProc.running = true;
    }

    function setInput(flag: string, value: string): void {
        root.actionText = qsTr("Applying…");
        actionProc.out = "";
        actionProc.command = ["horneroctl", "hypr", "input", "set", flag, value, "--yes", "--json"];
        actionProc.running = true;
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
        id: inputProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                inputProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(inputProc.out.trim());
                const d = payload.data ?? {};
                root.sensitivity = parseFloat(d.sensitivity ?? "0") || 0;
                root.accelProfile = d.accel_profile ?? "flat";
                root.repeatRate = parseInt(d.repeat_rate ?? "50") || 50;
                root.repeatDelay = parseInt(d.repeat_delay ?? "300") || 300;
                root.naturalScroll = (d.natural_scroll ?? "true") === "true";
                root.tapToClick = (d.tap_to_click ?? "true") === "true";
                root.compositor = d.compositor ?? "";
            } catch (e) {
                root.compositor = "";
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
                    text: qsTr("Keyboard layout and pointer/keyboard tuning; the keybindings editor arrives with #236.")
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

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: pointerCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: pointerCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Pointer & keyboard")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.compositor !== "hyprland"
                            text: qsTr("Pointer tuning needs the Hyprland backend (horneroctl hypr input); on this compositor it is unavailable and nothing is faked.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.compositor === "hyprland"
                            spacing: Appearance.spacing.small

                            SliderInput {
                                Layout.fillWidth: true
                                label: qsTr("Pointer sensitivity")
                                value: root.sensitivity
                                from: -1
                                to: 1
                                stepSize: 0.05
                                decimals: 2
                                validator: DoubleValidator {
                                    bottom: -1
                                    top: 1
                                }

                                onValueModified: newValue => root.setInput("--sensitivity", newValue.toString())
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                StyledText {
                                    text: qsTr("Acceleration")
                                    font.pointSize: Appearance.font.size.small
                                }

                                TextButton {
                                    text: qsTr("Adaptive")
                                    type: root.accelProfile === "adaptive" ? TextButton.Filled : TextButton.Tonal
                                    onClicked: root.setInput("--accel-profile", "adaptive")
                                }

                                TextButton {
                                    text: qsTr("Flat")
                                    type: root.accelProfile === "flat" ? TextButton.Filled : TextButton.Tonal
                                    onClicked: root.setInput("--accel-profile", "flat")
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Key repeat rate (per second)")
                                value: root.repeatRate
                                min: 1
                                max: 100
                                onValueModified: value => {
                                    root.setInput("--repeat-rate", Math.round(value).toString());
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Key repeat delay (ms)")
                                value: root.repeatDelay
                                min: 100
                                max: 1000
                                step: 50
                                onValueModified: value => {
                                    root.setInput("--repeat-delay", Math.round(value).toString());
                                }
                            }

                            ToggleRow {
                                label: qsTr("Touchpad natural scroll")
                                checked: root.naturalScroll
                                toggle.onToggled: {
                                    root.setInput("--natural-scroll", checked ? "true" : "false");
                                }
                            }

                            ToggleRow {
                                label: qsTr("Touchpad tap-to-click")
                                checked: root.tapToClick
                                toggle.onToggled: {
                                    root.setInput("--tap-to-click", checked ? "true" : "false");
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
    }

    InnerBorder {
        id: border

        leftThickness: 0
        rightThickness: Appearance.padding.normal
    }
}
