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

    // Every change goes through send(): one command at a time, a newer one
    // issued meanwhile replaces the queued one (newest wins), failures are
    // reported with the CLI's own message.
    property var queuedJob: null
    property var runningJob: null

    function send(cmd: var, undo: var): void {
        const job = {
            "cmd": cmd,
            "undo": undo ?? null
        };
        if (setProc.running) {
            root.queuedJob = job;
            return;
        }
        root.runningJob = job;
        root.actionText = qsTr("Applying…");
        setProc.out = "";
        setProc.command = cmd;
        setProc.running = true;
    }

    function scheduleArgs(from: string, to: string): var {
        return ["horneroctl", "appearance", "night-mode", "schedule", "set", "--from", from, "--to", to, "--yes", "--json"];
    }

    // The schedule switch and the time fields apply as you change them (the
    // times after a short pause, so typing 22:30 is one change, not four).
    function setSchedule(): void {
        const prev = root.schedule;
        const from = root.pad2(root.onHour) + ":" + root.pad2(root.onMinute);
        const to = root.pad2(root.offHour) + ":" + root.pad2(root.offMinute);
        if (prev === from + "-" + to)
            return;
        root.send(root.scheduleArgs(from, to), {
            "title": qsTr("Night light schedule %1 to %2").arg(from).arg(to),
            "restore": prev === "" ? ["horneroctl", "appearance", "night-mode", "schedule", "clear", "--yes", "--json"] : root.scheduleArgs(prev.split("-")[0], prev.split("-")[1]),
            "detail": prev === "" ? qsTr("Undo removes the schedule.") : qsTr("Undo returns to %1.").arg(prev)
        });
    }

    function clearSchedule(): void {
        const prev = root.schedule;
        root.send(["horneroctl", "appearance", "night-mode", "schedule", "clear", "--yes", "--json"], prev === "" ? null : {
            "title": qsTr("Night light schedule removed"),
            "restore": root.scheduleArgs(prev.split("-")[0], prev.split("-")[1]),
            "detail": qsTr("Undo brings back %1.").arg(prev)
        });
    }

    Timer {
        id: scheduleTimer

        interval: 700
        onTriggered: root.setSchedule()
    }

    function setMode(mode: string): void {
        root.send(["horneroctl", "appearance", "night-mode", mode, "--yes", "--json"], null);
    }

    function setTemperature(kelvin: int): void {
        root.send(["horneroctl", "appearance", "night-mode", "set", "--temperature", kelvin.toString(), "--yes", "--json"], null);
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Undo

        function onCommandFinished(key: string, ok: bool): void {
            if (key === "night-light")
                root.refresh();
        }
    }

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
        stderr: StdioCollector {
            id: setErr
        }
        onExited: (exitCode, exitStatus) => {
            const job = root.runningJob;
            root.runningJob = null;
            let ok = exitCode === 0;
            let message = "";
            try {
                const payload = JSON.parse(setProc.out.trim());
                message = payload.message ? payload.message.toString() : "";
                if (payload.ok === false)
                    ok = false;
            } catch (e) {
                ok = false;
                message = qsTr("The night-mode command did not answer. Check: horneroctl appearance night-mode status");
            }
            root.actionText = message;
            if (!ok) {
                Undo.report("night-light", qsTr("Night light was not changed"), message || setErr.text.trim().split("\n").slice(-1)[0]);
            } else if (job && job.undo) {
                const u = job.undo;
                // Undo runs the inverse command itself (it outlives this pane).
                Undo.offerCommand("night-light", u.title, u.restore, u.detail);
            }
            root.refresh();
            const next = root.queuedJob;
            root.queuedJob = null;
            if (next)
                root.send(next.cmd, next.undo);
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
                    paneId: "nightlight"
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                ChannelPanel {
                    title: qsTr("Warm the display for the night")

                    ColumnLayout {
                        id: nlCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: root.backend !== "" ? qsTr("Active backend: %1 · Available: %2").arg(root.backend).arg(root.available !== "" ? root.available : qsTr("none")) : qsTr("Available backends: %1").arg(root.available !== "" ? root.available : qsTr("none detected"))
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
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
                                font.weight: Appearance.font.weight.medium
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.schedule !== "" ? qsTr("On at %1 · Off at %2 · Enforced by timers: %3").arg(root.schedule.split("-")[0]).arg(root.schedule.split("-")[1]).arg(root.scheduleEnforced ? qsTr("yes") : qsTr("no")) : qsTr("No schedule set. Times use your local clock; timers catch up after login if a boundary was missed.")
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }

                            SwitchRow {
                                label: qsTr("Switch on and off automatically")
                                checked: root.schedule !== ""
                                onToggled: checked => {
                                    scheduleTimer.stop();
                                    if (checked)
                                        root.setSchedule();
                                    else
                                        root.clearSchedule();
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Turn on — hour")
                                value: root.onHour
                                min: 0
                                max: 23
                                onValueModified: value => {
                                    root.onHour = Math.round(value);
                                    if (root.schedule !== "")
                                        scheduleTimer.restart();
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
                                    if (root.schedule !== "")
                                        scheduleTimer.restart();
                                }
                            }

                            SpinBoxRow {
                                label: qsTr("Turn off — hour")
                                value: root.offHour
                                min: 0
                                max: 23
                                onValueModified: value => {
                                    root.offHour = Math.round(value);
                                    if (root.schedule !== "")
                                        scheduleTimer.restart();
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
                                    if (root.schedule !== "")
                                        scheduleTimer.restart();
                                }
                            }

                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.actionText !== ""
                            text: root.actionText
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Temperature applies immediately while Night Light is on and is stored for the next time otherwise. This pane never shows a control the backend cannot honour.")
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
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
