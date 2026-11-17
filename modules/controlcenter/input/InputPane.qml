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
    property string curLayout: ""
    property string curVariant: ""
    property string layoutsField: ""
    property string variantField: ""
    property int layoutCount: 0

    function applyLayoutSet(): void {
        if (root.layoutsField.trim() === "")
            return;
        root.actionText = qsTr("Applying…");
        const cmd = ["horneroctl", "hardware", "keyboard", "layout", "--set", root.layoutsField];
        if (root.variantField.trim() !== "")
            cmd.push("--variant", root.variantField);
        cmd.push("--yes", "--json");
        actionProc.out = "";
        actionProc.command = cmd;
        actionProc.running = true;
    }
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
        listProc.out = "";
        listProc.command = ["horneroctl", "hardware", "keyboard", "layout", "--list", "--json"];
        listProc.running = true;
        inputProc.out = "";
        inputProc.command = ["horneroctl", "hypr", "input", "status", "--json"];
        inputProc.running = true;
    }

    property string armedRestore: ""

    function restoreDefaults(kind: string, argv: var): void {
        if (root.armedRestore !== kind) {
            root.armedRestore = kind; // first click arms, second confirms
            return;
        }
        root.armedRestore = "";
        root.actionText = qsTr("Restoring…");
        actionProc.out = "";
        actionProc.command = argv;
        actionProc.running = true;
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
                const d = payload.data ?? {};
                root.curLayout = d.layout ?? "";
                root.curVariant = d.variant ?? "";
                if (root.layoutsField === "")
                    root.layoutsField = root.curLayout;
                if (root.variantField === "")
                    root.variantField = root.curVariant;
            } catch (e) {
                root.layoutText = qsTr("horneroctl keyboard unavailable on this system.");
            }
        }
    }

    Process {
        id: listProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                listProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(listProc.out.trim());
                const d = payload.data ?? {};
                root.layoutCount = parseInt(d.count ?? "0") || 0;
            } catch (e) {
                root.layoutCount = 0;
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
                spacing: Appearance.spacing.large

                PaneHeader {
                    paneId: "input"
                }

                ChannelPanel {
                    title: qsTr("Keyboard layout")
                    readoutAvailable: root.curLayout !== ""
                    readout: root.curVariant !== "" ? `${root.curLayout} (${root.curVariant})` : root.curLayout

                    SettingRow {
                        label: qsTr("Active layout")
                        description: root.layoutText

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
                            type: TextButton.Text
                            onClicked: root.refresh()
                        }
                    }

                    SettingRow {
                        label: qsTr("Layout list")
                        description: root.layoutCount > 0 ? qsTr("Comma-separated XKB names, e.g. us,latam. %1 layouts are available on this system.").arg(root.layoutCount) : qsTr("Comma-separated XKB names, e.g. us,latam")

                        below: [
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                Well {
                                    Layout.fillWidth: true
                                    implicitHeight: layoutsInput.implicitHeight + Appearance.padding.small * 2
                                    outline: layoutsInput.activeFocus ? Signal.palette.focus : Signal.palette.rule

                                    StyledTextField {
                                        id: layoutsInput

                                        anchors.fill: parent
                                        anchors.margins: Appearance.padding.small
                                        placeholderText: qsTr("us,latam")
                                        text: root.layoutsField
                                        onTextChanged: root.layoutsField = text
                                        onAccepted: root.applyLayoutSet()
                                    }
                                }

                                Well {
                                    Layout.preferredWidth: 160
                                    implicitHeight: variantInput.implicitHeight + Appearance.padding.small * 2
                                    outline: variantInput.activeFocus ? Signal.palette.focus : Signal.palette.rule

                                    StyledTextField {
                                        id: variantInput

                                        anchors.fill: parent
                                        anchors.margins: Appearance.padding.small
                                        placeholderText: qsTr("Variant (intl,)")
                                        text: root.variantField
                                        onTextChanged: root.variantField = text
                                        onAccepted: root.applyLayoutSet()
                                    }
                                }

                                TextButton {
                                    text: qsTr("Apply layouts")
                                    type: TextButton.Filled
                                    enabled: root.layoutsField.trim() !== ""
                                    onClicked: root.applyLayoutSet()
                                }
                            }
                        ]
                    }

                    SettingRow {
                        visible: root.actionText !== ""
                        label: root.actionText
                    }
                }

                ChannelPanel {
                    title: qsTr("Pointer and keys")
                    readoutAvailable: root.compositor === "hyprland"
                    readout: root.compositor === "hyprland" ? qsTr("live (Hyprland)") : ""

                    SettingRow {
                        visible: root.compositor !== "hyprland"
                        label: qsTr("Unavailable on this session")
                        description: qsTr("Pointer tuning needs the Hyprland backend (horneroctl hypr input); nothing is faked.")
                    }

                    SettingRow {
                        visible: root.compositor === "hyprland"

                        below: [
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
                        ]
                    }

                    SettingRow {
                        visible: root.compositor === "hyprland"
                        label: qsTr("Acceleration")

                        SegmentedControl {
                            accessibleName: qsTr("Acceleration")
                            model: [qsTr("Adaptive"), qsTr("Flat")]
                            currentIndex: root.accelProfile === "adaptive" ? 0 : 1
                            onActivated: index => root.setInput("--accel-profile", index === 0 ? "adaptive" : "flat")
                        }
                    }

                    SettingRow {
                        visible: root.compositor === "hyprland"
                        label: qsTr("Key repeat rate")
                        description: qsTr("Per second")

                        CustomSpinBox {
                            min: 1
                            max: 100
                            step: 1
                            value: root.repeatRate
                            onValueModified: value => root.setInput("--repeat-rate", Math.round(value).toString())
                        }
                    }

                    SettingRow {
                        visible: root.compositor === "hyprland"
                        label: qsTr("Key repeat delay")
                        description: qsTr("Milliseconds")

                        CustomSpinBox {
                            min: 100
                            max: 1000
                            step: 50
                            value: root.repeatDelay
                            onValueModified: value => root.setInput("--repeat-delay", Math.round(value).toString())
                        }
                    }

                    SettingRow {
                        visible: root.compositor === "hyprland"
                        label: qsTr("Touchpad natural scroll")

                        StyledSwitch {
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: qsTr("Touchpad natural scroll")
                            Accessible.checked: checked
                            checked: root.naturalScroll
                            onToggled: root.setInput("--natural-scroll", checked ? "true" : "false")
                        }
                    }

                    SettingRow {
                        visible: root.compositor === "hyprland"
                        label: qsTr("Touchpad tap-to-click")

                        StyledSwitch {
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: qsTr("Touchpad tap-to-click")
                            Accessible.checked: checked
                            checked: root.tapToClick
                            onToggled: root.setInput("--tap-to-click", checked ? "true" : "false")
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Restore defaults")

                    SettingRow {
                        label: qsTr("Re-apply saved settings")
                        description: qsTr("Each restore asks for a second click to confirm.")

                        below: [
                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                TextButton {
                                    text: root.armedRestore === "keyboard" ? qsTr("Click again to restore layout") : qsTr("Restore keyboard layout")
                                    type: root.armedRestore === "keyboard" ? TextButton.Filled : TextButton.Tonal
                                    onClicked: root.restoreDefaults("keyboard", ["horneroctl", "hardware", "keyboard", "layout", "--restore", "--yes", "--json"])
                                }

                                TextButton {
                                    text: root.armedRestore === "input" ? qsTr("Click again to restore tuning") : qsTr("Restore pointer & keyboard")
                                    type: root.armedRestore === "input" ? TextButton.Filled : TextButton.Tonal
                                    onClicked: root.restoreDefaults("input", ["horneroctl", "hypr", "input", "restore", "--yes", "--json"])
                                }

                                TextButton {
                                    text: root.armedRestore === "cursor" ? qsTr("Click again to restore cursor") : qsTr("Restore cursor")
                                    type: root.armedRestore === "cursor" ? TextButton.Filled : TextButton.Tonal
                                    onClicked: root.restoreDefaults("cursor", ["horneroctl", "hypr", "cursor", "restore", "--yes", "--json"])
                                }
                            }
                        ]
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
