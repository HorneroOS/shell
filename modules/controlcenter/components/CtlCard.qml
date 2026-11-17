pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Read-only horneroctl probe card with an optional two-step mutating
// action. QML only ever runs the allowlisted argv its caller passes in
// (always `horneroctl --json …` / a confirmed `--yes` leaf); it never
// builds shell strings. Shows loading, error, empty and result states.
StyledRect {
    id: root

    required property string title
    property string description: ""
    required property var probeArgv
    property string actionLabel: ""
    property var actionArgv: []
    property bool autoRun: false

    property string resultText: ""
    property string errorText: ""
    property bool ran: false
    property bool armed: false

    Layout.fillWidth: true
    radius: Appearance.rounding.small
    color: Signal.layer(Signal.palette.panel, 1)
    implicitHeight: col.implicitHeight + Appearance.padding.large * 2

    function envelope(text: string): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    // Split the result into rows. `key : value` (horneroctl's status and
    // doctor layout) gives a labelled row; anything else keeps its line.
    function resultRows(): var {
        const rows = [];
        for (const raw of root.resultText.split("\n")) {
            const line = raw.trim();
            if (line === "")
                continue;
            const match = line.match(/^([A-Za-z0-9_.-]+)\s*:\s*(.*)$/);
            if (match)
                rows.push({ key: match[1], value: match[2] });
            else
                rows.push({ key: "", value: line });
        }
        return rows;
    }

    function runProbe(): void {
        if (probeProc.running)
            return;
        root.armed = false;
        root.errorText = "";
        probeProc.command = root.probeArgv;
        probeProc.running = true;
    }

    function runAction(): void {
        if (actionProc.running || root.actionArgv.length === 0)
            return;
        if (!root.armed) {
            root.armed = true; // first click arms, second confirms
            return;
        }
        root.armed = false;
        root.errorText = "";
        actionProc.command = root.actionArgv;
        actionProc.running = true;
    }

    Component.onCompleted: {
        if (root.autoRun)
            root.runProbe();
    }

    Process {
        id: probeProc

        stdout: StdioCollector {
            onStreamFinished: {
                const env = root.envelope(text);
                root.ran = true;
                if (!env) {
                    root.errorText = qsTr("horneroctl did not answer with JSON.");
                    root.resultText = "";
                    return;
                }
                root.resultText = String(env.message ?? "");
                root.errorText = env.ok === true ? "" : root.resultText;
                if (env.ok === true && root.resultText.trim() === "")
                    root.resultText = qsTr("No data reported.");
            }
        }
        onExited: (exitCode, exitStatus) => {
            if ((exitCode !== 0 || exitStatus !== 0) && !root.ran)
                root.errorText = qsTr("Probe failed (exit %1).").arg(exitCode);
        }
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            onStreamFinished: {
                const env = root.envelope(text);
                root.resultText = env ? String(env.message ?? "") : text.trim();
                root.errorText = env && env.ok !== true ? root.resultText : "";
                root.ran = true;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.actionArgv.length > 0)
                root.runProbe();
        }
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: root.title
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 500
                }

                StyledText {
                    visible: root.description !== ""
                    Layout.fillWidth: true
                    text: root.description
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }
            }

            TextButton {
                text: probeProc.running ? qsTr("Running…") : root.ran ? qsTr("Run again") : qsTr("Run")
                type: TextButton.Tonal
                enabled: !probeProc.running && !actionProc.running
                onClicked: root.runProbe()
            }

            TextButton {
                visible: root.actionLabel !== ""
                text: root.armed ? qsTr("Click again to confirm") : root.actionLabel
                type: root.armed ? TextButton.Filled : TextButton.Tonal
                enabled: !probeProc.running && !actionProc.running
                onClicked: root.runAction()
            }
        }

        StyledText {
            visible: probeProc.running || actionProc.running
            text: qsTr("Working…")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
        }

        StyledText {
            visible: !probeProc.running && !actionProc.running && root.errorText !== ""
            Layout.fillWidth: true
            text: root.errorText
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        // Key/value results (`key : value` lines from horneroctl) read as
        // a two-column table: quiet label, mono value that wraps inside
        // its column. Any other line falls back to a full-width row.
        ColumnLayout {
            visible: !probeProc.running && !actionProc.running && root.errorText === "" && root.resultText !== ""
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: root.resultRows()

                delegate: RowLayout {
                    id: resultRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        visible: resultRow.modelData.key !== ""
                        Layout.preferredWidth: 120
                        Layout.maximumWidth: 120
                        Layout.alignment: Qt.AlignTop
                        text: resultRow.modelData.key
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        wrapMode: Text.WrapAnywhere
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: resultRow.modelData.value
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.ink
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }

        StyledText {
            visible: !root.ran && !probeProc.running
            Layout.fillWidth: true
            text: qsTr("Not run yet.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.ruleStrong
        }
    }
}
