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

// Control Center › Windows (shell#235): window geometry (gaps,
// border, rounding), focus follow-mouse, and user float/pin rules
// through `horneroctl hypr windows` (its own bounded, confirmed
// writer; subset sets keep the untouched values). Rules live in the
// user window-rules overlay and apply on Hyprland reload/restart.
// This pane never hand-edits compositor config, and Niri window
// behaviour is not faked here.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property int gapsIn: 5
    property int gapsOut: 20
    property int borderSize: 2
    property int rounding: 10
    property int followMouse: 1
    property string statusText: qsTr("Reading window geometry…")
    property string actionText: ""
    property var rules: []
    property string ruleMatch: "class"
    property string rulePattern: ""
    property string ruleEffect: "float"
    property string rulesText: ""

    function ruleName(line: string): string {
        const i = line.indexOf(":");
        return i > 0 ? line.slice(0, i) : "";
    }

    function refreshRules(): void {
        rulesProc.out = "";
        rulesProc.command = ["horneroctl", "hypr", "windows", "rules", "list", "--json"];
        rulesProc.running = true;
    }

    function addRule(): void {
        if (root.rulePattern.trim() === "")
            return;
        root.rulesText = qsTr("Adding…");
        ruleActionProc.out = "";
        ruleActionProc.command = ["horneroctl", "hypr", "windows", "rules", "add", "--match", root.ruleMatch, "--pattern", root.rulePattern, "--effect", root.ruleEffect, "--yes", "--json"];
        ruleActionProc.running = true;
    }

    function removeRule(name: string): void {
        if (name === "")
            return;
        root.rulesText = qsTr("Removing…");
        ruleActionProc.out = "";
        ruleActionProc.command = ["horneroctl", "hypr", "windows", "rules", "remove", "--name", name, "--yes", "--json"];
        ruleActionProc.running = true;
    }

    function refresh(): void {
        statusProc.out = "";
        statusProc.command = ["horneroctl", "hypr", "windows", "status", "--json"];
        statusProc.running = true;
        root.refreshRules();
    }

    function apply(flag: string, value: int): void {
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = ["horneroctl", "hypr", "windows", "set", flag, value.toString(), "--yes", "--json"];
        setProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: statusProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                statusProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(statusProc.out.trim());
                const d = payload.data ?? {};
                root.gapsIn = parseInt(d.gaps_in ?? "5");
                root.gapsOut = parseInt(d.gaps_out ?? "20");
                root.borderSize = parseInt(d.border_size ?? "2");
                root.rounding = parseInt(d.rounding ?? "10");
                root.followMouse = parseInt(d.follow_mouse ?? "1");
                root.statusText = payload.ok ? qsTr("Live from Hyprland via horneroctl") : payload.message.toString();
            } catch (e) {
                root.statusText = qsTr("horneroctl windows unavailable on this system.");
            }
        }
    }

    Process {
        id: setProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                setProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(setProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.actionText = qsTr("The windows command did not answer. Check: horneroctl hypr windows status");
            }
            root.refresh();
        }
    }

    Process {
        id: rulesProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                rulesProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(rulesProc.out.trim());
                const msg = (payload.message ?? "").toString();
                root.rules = payload.ok && !msg.startsWith("No user window rules") ? msg.split("\n").filter(l => l.trim() !== "") : [];
            } catch (e) {
                root.rules = [];
            }
        }
    }

    Process {
        id: ruleActionProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                ruleActionProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(ruleActionProc.out.trim());
                root.rulesText = payload.message ? payload.message.toString() : "";
                if (payload.ok)
                    root.rulePattern = "";
            } catch (e) {
                root.rulesText = qsTr("The rules command did not answer. Check: horneroctl hypr windows rules list");
            }
            root.refreshRules();
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
                    text: qsTr("Windows")
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
                    implicitHeight: geoCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: geoCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.normal

                        StyledText {
                            text: qsTr("Geometry (Hyprland)")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Inner gaps")
                            value: root.gapsIn
                            from: 0
                            to: 100
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 100
                            }
                            onValueModified: newValue => root.apply("--gaps-in", Math.round(newValue))
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Outer gaps")
                            value: root.gapsOut
                            from: 0
                            to: 200
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 200
                            }
                            onValueModified: newValue => root.apply("--gaps-out", Math.round(newValue))
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Border size")
                            value: root.borderSize
                            from: 0
                            to: 20
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 20
                            }
                            onValueModified: newValue => root.apply("--border-size", Math.round(newValue))
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Corner rounding")
                            value: root.rounding
                            from: 0
                            to: 60
                            stepSize: 1
                            suffix: "px"
                            validator: IntValidator {
                                bottom: 0
                                top: 60
                            }
                            onValueModified: newValue => root.apply("--rounding", Math.round(newValue))
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Restore saved")
                                type: TextButton.Tonal
                                onClicked: {
                                    root.actionText = qsTr("Restoring…");
                                    setProc.out = "";
                                    setProc.command = ["horneroctl", "hypr", "windows", "restore", "--yes", "--json"];
                                    setProc.running = true;
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

                        SliderInput {
                            Layout.fillWidth: true
                            label: qsTr("Focus follows mouse (0 off, 1 loose, 2 strict)")
                            value: root.followMouse
                            from: 0
                            to: 2
                            stepSize: 1
                            validator: IntValidator {
                                bottom: 0
                                top: 2
                            }
                            onValueModified: newValue => root.apply("--follow-mouse", Math.round(newValue))
                        }

                        StyledText {
                            text: qsTr("Window rules (float / pin)")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        Repeater {
                            model: root.rules

                            delegate: RowLayout {
                                required property string modelData

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.family: Appearance.font.family.mono
                                    font.pointSize: Appearance.font.size.small
                                    color: Colours.palette.m3onSurface
                                    wrapMode: Text.Wrap
                                }

                                TextButton {
                                    text: qsTr("Remove")
                                    type: TextButton.Tonal
                                    onClicked: root.removeRule(root.ruleName(modelData))
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.rules.length === 0
                            text: qsTr("No user window rules.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: root.ruleMatch === "class" ? qsTr("Match: class") : qsTr("Match: title")
                                type: TextButton.Tonal
                                onClicked: root.ruleMatch = root.ruleMatch === "class" ? "title" : "class"
                            }

                            StyledTextField {
                                Layout.fillWidth: true
                                placeholderText: qsTr("kitty or ^kitty$")
                                text: root.rulePattern
                                onTextChanged: root.rulePattern = text
                                onAccepted: root.addRule()
                            }

                            TextButton {
                                text: root.ruleEffect === "float" ? qsTr("Effect: float") : qsTr("Effect: pin")
                                type: TextButton.Tonal
                                onClicked: root.ruleEffect = root.ruleEffect === "float" ? "pin" : "float"
                            }

                            TextButton {
                                text: qsTr("Add rule")
                                type: TextButton.Filled
                                enabled: root.rulePattern.trim() !== ""
                                onClicked: root.addRule()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.rulesText !== ""
                            text: root.rulesText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Rules are stored in your window-rules overlay and take effect on Hyprland config reload (Super+Shift+R) or restart; already-open windows are unaffected. Geometry and focus apply live and are restored at login.")
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
