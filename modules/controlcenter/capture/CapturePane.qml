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

// Control Center › Capture (shell#237): screenshot and screen-recording
// state plus the actions horneroctl capture already owns. The CLI owns
// the backends (sss / Niri native, gpu-screen-recorder), the recorder
// state files, and the output directories; this pane only surfaces
// `horneroctl capture status` and runs the existing leaves. Controls
// only appear when the backend that would honour them is present —
// there are no format/quality knobs because the backend has none.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property string screenshotBackendName: ""
    property string screenshotBackend: ""
    property bool screenshotPresent: false
    property string recorderBackend: ""
    property bool recorderPresent: false
    property bool recording: false
    property bool recordingPaused: false
    property string currentFile: ""
    property string picturesDir: ""
    property string recordingsDir: ""
    property string clipboardState: ""

    property string statusText: qsTr("Reading capture state…")
    property string actionText: ""
    property bool busy: false

    function refresh(): void {
        statusProc.out = "";
        statusProc.command = ["horneroctl", "capture", "status", "--json"];
        statusProc.running = true;
    }

    function runAction(argv: var): void {
        if (root.busy)
            return;
        root.busy = true;
        root.actionText = qsTr("Working…");
        actionProc.out = "";
        actionProc.command = argv;
        actionProc.running = true;
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
                root.screenshotBackendName = d.screenshot_backend_name ?? "";
                root.screenshotBackend = d.screenshot_backend ?? "";
                root.screenshotPresent = (d.screenshot_backend_present ?? "false") === "true";
                root.recorderBackend = d.recorder_backend ?? "";
                root.recorderPresent = (d.recorder_backend_present ?? "false") === "true";
                root.recording = (d.recorder_running ?? "false") === "true";
                root.recordingPaused = (d.recorder_paused ?? "false") === "true";
                root.currentFile = d.recorder_current_file ?? "";
                root.picturesDir = d.pictures_dir ?? "";
                root.recordingsDir = d.recordings_dir ?? "";
                const clip = (name, key) => name + ((d[key] ?? "false") === "true" ? " ✓" : " ✗");
                root.clipboardState = [clip("copyq", "clipboard_copyq_present"), clip("cliphist", "clipboard_cliphist_present"), clip("wl-paste", "clipboard_wl_paste_present")].join(" · ");
                root.statusText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.statusText = qsTr("horneroctl capture status is unavailable on this system (needs a horneroctl with the capture status verb).");
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
            root.busy = false;
            try {
                const payload = JSON.parse(actionProc.out.trim());
                root.actionText = payload.message ? payload.message.toString() : "";
            } catch (e) {
                root.actionText = qsTr("The capture command did not answer. Check: horneroctl capture status");
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
                    text: qsTr("Capture")
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
                    implicitHeight: capCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: capCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Screenshots")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.screenshotPresent ? qsTr("Backend: %1 (%2) · Saved to %3").arg(root.screenshotBackendName).arg(root.screenshotBackend).arg(root.picturesDir) : qsTr("No screenshot backend detected (sss, or Niri in a Niri session).")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Take screenshot")
                                type: TextButton.Filled
                                enabled: root.screenshotPresent && !root.busy
                                onClicked: root.runAction(["horneroctl", "capture", "screenshot", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Select region")
                                type: TextButton.Tonal
                                enabled: root.screenshotPresent && !root.busy
                                onClicked: root.runAction(["horneroctl", "capture", "screenshot", "--region", "--yes", "--json"])
                            }
                        }

                        StyledText {
                            text: qsTr("Screen recording")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.recorderPresent ? (root.recording ? (root.recordingPaused ? qsTr("Recording (paused): %1").arg(root.currentFile) : qsTr("Recording: %1").arg(root.currentFile)) : qsTr("Recorder ready (gpu-screen-recorder) · Saved to %1").arg(root.recordingsDir)) : qsTr("gpu-screen-recorder is not installed; recording controls stay hidden until it is.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                visible: root.recorderPresent && !root.recording
                                text: qsTr("Start recording")
                                type: TextButton.Filled
                                enabled: !root.busy
                                onClicked: root.runAction(["horneroctl", "capture", "record", "start", "--yes", "--json"])
                            }

                            TextButton {
                                visible: root.recorderPresent && root.recording
                                text: root.recordingPaused ? qsTr("Resume") : qsTr("Pause")
                                type: TextButton.Tonal
                                enabled: !root.busy
                                onClicked: root.runAction(["horneroctl", "capture", "record", "pause", "--yes", "--json"])
                            }

                            TextButton {
                                visible: root.recorderPresent && root.recording
                                text: qsTr("Stop recording")
                                type: TextButton.Filled
                                enabled: !root.busy
                                onClicked: root.runAction(["horneroctl", "capture", "record", "stop", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: root.refresh()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.clipboardState !== ""
                            text: qsTr("Clipboard backends: %1").arg(root.clipboardState)
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.Wrap
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
                            text: qsTr("Screenshot and recording defaults live in horneroctl capture (XDG pictures/videos directories); this pane never shows a control the backend cannot honour.")
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
