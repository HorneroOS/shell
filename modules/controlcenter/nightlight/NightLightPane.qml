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

// Control Center › Night Light (shell#225): manual on/off, a
// temperature slider, and schedule controls over
// `horneroctl appearance night-mode` — the CLI owns the
// temperature backends (redshift/gammastep/wlsunset/xrandr), the
// stored temperature, and the systemd user timers that enforce
// the schedule. Controls only appear when a backend exists to
// honour them.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property bool active: false
    property string backend: ""
    property string available: ""
    property int temperature: 4000
    property string schedule: ""
    property bool scheduleEnforced: false
    property int onHour: 22
    property int onMinute: 0
    property int offHour: 7
    property int offMinute: 0

    function pad2(n: int): string {
        return (n < 10 ? "0" : "") + n;
    }

    function setSchedule(): void {
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = ["horneroctl", "appearance", "night-mode", "schedule", "set", "--from", root.pad2(root.onHour) + ":" + root.pad2(root.onMinute), "--to", root.pad2(root.offHour) + ":" + root.pad2(root.offMinute), "--yes", "--json"];
        setProc.running = true;
    }

    function clearSchedule(): void {
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = ["horneroctl", "appearance", "night-mode", "schedule", "clear", "--yes", "--json"];
        setProc.running = true;
    }
    property string statusText: qsTr("Reading night light…")
    property string actionText: ""

    function refresh(): void {
        statusProc.out = "";
        statusProc.command = ["horneroctl", "appearance", "night-mode", "status", "--json"];
        statusProc.running = true;
        backendsProc.out = "";
        backendsProc.command = ["horneroctl", "appearance", "night-mode", "backends", "--json"];
        backendsProc.running = true;
    }

    function setMode(mode: string): void {
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = ["horneroctl", "appearance", "night-mode", mode, "--yes", "--json"];
        setProc.running = true;
    }

    function setTemperature(kelvin: int): void {
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = ["horneroctl", "appearance", "night-mode", "set", "--temperature", kelvin.toString(), "--yes", "--json"];
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
                root.active = (d.active ?? "false") === "true";
                root.backend = d.backend ?? "";
                root.temperature = parseInt(d.temperature ?? "4000") || 4000;
                root.schedule = d.schedule ?? "";
                root.scheduleEnforced = (d.scheduleEnforced ?? "false") === "true";
                if (root.schedule !== "") {
                    const win = root.schedule.split("-");
                    if (win.length === 2) {
                        const onParts = win[0].split(":");
                        const offParts = win[1].split(":");
                        root.onHour = parseInt(onParts[0]) || 0;
                        root.onMinute = parseInt(onParts[1]) || 0;
                        root.offHour = parseInt(offParts[0]) || 0;
                        root.offMinute = parseInt(offParts[1]) || 0;
                    }
                }
                root.statusText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.statusText = qsTr("horneroctl night-mode unavailable on this system.");
            }
        }
    }

    Process {
        id: backendsProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                backendsProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(backendsProc.out.trim());
                root.available = (payload.data ?? {}).available ?? "";
            } catch (e) {
                root.available = "";
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
                root.actionText = qsTr("The night-mode command did not answer. Check: horneroctl appearance night-mode status");
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
                    text: qsTr("Night Light")
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
                    implicitHeight: nlCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: nlCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Warm the display for the night")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.backend !== "" ? qsTr("Active backend: %1 · Available: %2").arg(root.backend).arg(root.available !== "" ? root.available : qsTr("none")) : qsTr("Available backends: %1").arg(root.available !== "" ? root.available : qsTr("none detected"))
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: root.active ? qsTr("Turn off") : qsTr("Turn on")
                                type: TextButton.Filled
                                onClicked: root.setMode(root.active ? "off" : "on")
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: root.refresh()
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true
                            visible: root.available !== ""
                            label: qsTr("Temperature")
                            value: root.temperature
                            from: 1000
                            to: 6500
                            stepSize: 100
                            decimals: 0
                            suffix: "K"
                            validator: IntValidator {
                                bottom: 1000
                                top: 6500
                            }

                            onValueModified: newValue => root.setTemperature(Math.round(newValue))
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.available !== ""
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: qsTr("Schedule")
                                font.pointSize: Appearance.font.size.normal
                                font.weight: 500
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.schedule !== "" ? qsTr("On at %1 · Off at %2 · Enforced by timers: %3").arg(root.schedule.split("-")[0]).arg(root.schedule.split("-")[1]).arg(root.scheduleEnforced ? qsTr("yes") : qsTr("no")) : qsTr("No schedule set. Times use your local clock; timers catch up after login if a boundary was missed.")
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                            }

                            SpinBoxRow {
                                label: qsTr("Turn on — hour")
                                value: root.onHour
                                min: 0
                                max: 23
                                onValueModified: value => {
                                    root.onHour = Math.round(value);
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Turn on — minutes")
                                value: root.onMinute
                                min: 0
                                max: 59
                                step: 5
                                onValueModified: value => {
                                    root.onMinute = Math.round(value);
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Turn off — hour")
                                value: root.offHour
                                min: 0
                                max: 23
                                onValueModified: value => {
                                    root.offHour = Math.round(value);
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Turn off — minutes")
                                value: root.offMinute
                                min: 0
                                max: 59
                                step: 5
                                onValueModified: value => {
                                    root.offMinute = Math.round(value);
                                }
                            }

                            RowLayout {
                                spacing: Appearance.spacing.small

                                TextButton {
                                    text: qsTr("Set schedule")
                                    type: TextButton.Filled
                                    onClicked: root.setSchedule()
                                }

                                TextButton {
                                    visible: root.schedule !== ""
                                    text: qsTr("Clear schedule")
                                    type: TextButton.Tonal
                                    onClicked: root.clearSchedule()
                                }
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

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Temperature applies immediately while Night Light is on and is stored for the next time otherwise. This pane never shows a control the backend cannot honour.")
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
