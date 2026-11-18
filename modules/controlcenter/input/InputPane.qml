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

    // Layout changes can lock you out of typing, so they offer Undo
    // (docs/CONTROL-CENTER-APPLY.md). The fields commit on Enter or when they
    // lose focus, never per keystroke. One CLI call runs at a time; a newer
    // value typed meanwhile is applied right after (newest wins).
    property bool layoutQueued: false
    property var layoutUndo: null

    function applyLayoutSet(): void {
        if (root.layoutsField.trim() === "")
            return;
        if (root.layoutsField.trim() === root.curLayout && root.variantField.trim() === root.curVariant)
            return;
        if (actionProc.running) {
            root.layoutQueued = true;
            return;
        }
        root.layoutUndo = {
            "layout": root.curLayout,
            "variant": root.curVariant,
            "title": root.layoutsField.trim()
        };
        root.runLayoutSet(root.layoutsField, root.variantField);
    }

    // Without --variant the CLI clears the variant, so an empty one is simply left out.
    function layoutArgs(layouts: string, variant: string): var {
        const cmd = ["horneroctl", "hardware", "keyboard", "layout", "--set", layouts.trim()];
        if (variant.trim() !== "")
            cmd.push("--variant", variant.trim());
        cmd.push("--yes", "--json");
        return cmd;
    }

    function runLayoutSet(layouts: string, variant: string): void {
        root.actionText = qsTr("Applying…");
        actionProc.out = "";
        actionProc.command = root.layoutArgs(layouts, variant);
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

    // Re-applying what is already saved changes nothing you have not chosen,
    // so it runs at once (no second click); the live state is re-read after.
    function restoreDefaults(kind: string, argv: var): void {
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

    Connections {
        target: Undo

        function onCommandFinished(key: string, ok: bool): void {
            if (key === "input-layout") {
                root.layoutsField = "";
                root.variantField = "";
                root.refresh();
            }
        }
    }

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
            let message = "";
            let ok = exitCode === 0;
            try {
                const payload = JSON.parse(actionProc.out.trim());
                message = payload.message ? payload.message.toString() : "";
                if (payload.ok === false)
                    ok = false;
            } catch (e) {
                message = "";
            }
            root.actionText = message;
            const undo = root.layoutUndo;
            if (undo) {
                root.layoutUndo = null;
                if (!ok) {
                    // The CLI validates before it writes: nothing changed.
                    Undo.report("input-layout", qsTr("Keyboard layout was not changed"), message || qsTr("horneroctl refused the layout list."));
                    root.layoutsField = undo.layout;
                    root.variantField = undo.variant;
                } else if (undo.layout !== "") {
                    // Undo runs the inverse command itself (it outlives this pane).
                    Undo.offerCommand("input-layout", qsTr("Keyboard layout %1").arg(undo.title), root.layoutArgs(undo.layout, undo.variant), qsTr("Undo returns to %1.").arg(undo.layout));
                }
            }
            root.refresh();
            if (root.layoutQueued) {
                root.layoutQueued = false;
                Qt.callLater(root.applyLayoutSet);
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
                        description: root.layoutCount > 0 ? qsTr("Comma-separated XKB names, e.g. us,latam. Applies when you press Enter or leave the field. %1 layouts are available on this system.").arg(root.layoutCount) : qsTr("Comma-separated XKB names, e.g. us,latam. Applies when you press Enter or leave the field.")

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
                                        onEditingFinished: root.applyLayoutSet()
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
                                        onEditingFinished: root.applyLayoutSet()
                                    }
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
                        description: qsTr("Puts the settings you saved back on the running session.")

                        below: [
                            Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                TextButton {
                                    text: qsTr("Restore keyboard layout")
                                    type: TextButton.Tonal
                                    onClicked: root.restoreDefaults("keyboard", ["horneroctl", "hardware", "keyboard", "layout", "--restore", "--yes", "--json"])
                                }

                                TextButton {
                                    text: qsTr("Restore pointer & keyboard")
                                    type: TextButton.Tonal
                                    onClicked: root.restoreDefaults("input", ["horneroctl", "hypr", "input", "restore", "--yes", "--json"])
                                }

                                TextButton {
                                    text: qsTr("Restore cursor")
                                    type: TextButton.Tonal
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
