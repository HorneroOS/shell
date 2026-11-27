pragma ComponentBehavior: Bound

import ".."
import "../components"
import "../../../services/profiles.js" as Profiles
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Control Center › Audio. One column, three channels: Output, Input and
// Applications. Every number is read from the PipeWire service through
// the Audio singleton; with no default device the level rows say
// "unavailable". The meters show the set level of each node, not a live
// signal peak.
Item {
    id: root

    required property Session session

    anchors.fill: parent

    property bool routingAvailable: false
    property bool routingBusy: false
    property var routingStreams: []
    property var routingSinks: []
    property var zeroVolumeStreams: []
    property string routingError: ""

    function refreshRouting(): void {
        if (routingProc.running)
            return;
        routingProc.command = ["horneroctl", "--json", "studio", "routing", "status"];
        routingProc.running = true;
    }

    function fixStreamVolume(streamId: string): void {
        if (root.routingBusy || routingMutProc.running || streamId.length === 0)
            return;
        root.routingBusy = true;
        root.routingError = "";
        routingMutProc.command = ["horneroctl", "--json", "studio", "routing", "fix-volume", streamId, "100", "--yes"];
        routingMutProc.running = true;
    }

    function moveStreamToSink(streamId: string, sinkName: string): void {
        if (root.routingBusy || routingMutProc.running || streamId.length === 0 || sinkName.length === 0)
            return;
        root.routingBusy = true;
        root.routingError = "";
        routingMutProc.command = ["horneroctl", "--json", "studio", "routing", "move-stream", streamId, sinkName, "--yes"];
        routingMutProc.running = true;
    }

    function sinkLabel(sinkName: string): string {
        for (let i = 0; i < root.routingSinks.length; i++) {
            const sk = root.routingSinks[i];
            if (sk.name === sinkName || sk.id === sinkName)
                return sk.description || sk.name || sinkName;
        }
        return sinkName.length > 0 ? sinkName : qsTr("Default");
    }

    Component.onCompleted: root.refreshRouting()

    Connections {
        target: Audio

        function onStreamsChanged(): void {
            routingDebounce.restart();
        }
    }

    Timer {
        id: routingDebounce

        interval: 250
        repeat: false
        onTriggered: root.refreshRouting()
    }

    Process {
        id: routingProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Profiles.parseRoutingStatus(text);
                root.routingAvailable = res.available;
                root.routingStreams = res.streams;
                root.routingSinks = res.sinks;
                root.zeroVolumeStreams = res.zeroVolumeStreams;
                if (res.available)
                    root.routingError = "";
            }
        }
        onExited: (exitCode, exitStatus) => {
            if ((exitCode !== 0 || exitStatus !== 0) && !root.routingAvailable) {
                root.routingStreams = [];
                root.routingSinks = [];
                root.zeroVolumeStreams = [];
            }
        }
    }

    Process {
        id: routingMutProc

        stdout: StdioCollector {
            onStreamFinished: {
                const res = Profiles.parseProfileApply(text);
                if (!res.ok)
                    root.routingError = res.error || qsTr("Routing update failed.");
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0 && root.routingError.length === 0)
                    root.routingError = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.routingBusy = false;
            if ((exitCode !== 0 || exitStatus !== 0) && root.routingError.length === 0)
                root.routingError = qsTr("Routing update failed (exit %1).").arg(exitCode);
            root.refreshRouting();
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
            contentHeight: contentLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: contentLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: implicitHeight
                spacing: Appearance.spacing.large

                PaneHeader {
                    paneId: "audio"
                }

                ChannelPanel {
                    title: qsTr("Output")
                    readoutAvailable: Audio.sink !== null
                    readout: Audio.sink ? qsTr("%1 devices").arg(Audio.sinks.length) : ""

                    StreamLevel {
                        name: Audio.sink?.description || qsTr("No output device")
                        glyph: "device-speaker"
                        available: !!Audio.sink?.audio
                        level: Audio.volume
                        muted: Audio.muted
                        sliderName: qsTr("Output volume")
                        muteName: qsTr("Mute output")
                        onLevelMoved: value => Audio.setVolume(value)
                        onMuteToggled: muted => {
                            if (Audio.sink?.audio)
                                Audio.sink.audio.muted = muted;
                        }
                    }

                    Repeater {
                        model: Audio.sinks

                        delegate: DeviceRow {
                            required property var modelData

                            label: modelData.description
                            detail: modelData.name
                            glyph: Audio.sink?.id === modelData.id ? "device-speaker" : "devices"
                            current: Audio.sink?.id === modelData.id
                            currentSpoken: qsTr(", current output")
                            onActivated: Audio.setAudioSink(modelData)
                        }
                    }

                    SettingRow {
                        visible: Audio.sinks.length === 0
                        label: qsTr("No output devices found")
                        description: qsTr("PipeWire reported no sinks. Check that PipeWire and WirePlumber are running.")
                    }
                }

                ChannelPanel {
                    title: qsTr("Input")
                    readoutAvailable: Audio.source !== null
                    readout: Audio.source ? qsTr("%1 devices").arg(Audio.sources.length) : ""

                    StreamLevel {
                        name: Audio.source?.description || qsTr("No input device")
                        glyph: "microphone"
                        available: !!Audio.source?.audio
                        level: Audio.sourceVolume
                        muted: Audio.sourceMuted
                        sliderName: qsTr("Input volume")
                        muteName: qsTr("Mute input")
                        onLevelMoved: value => Audio.setSourceVolume(value)
                        onMuteToggled: muted => {
                            if (Audio.source?.audio)
                                Audio.source.audio.muted = muted;
                        }
                    }

                    Repeater {
                        model: Audio.sources

                        delegate: DeviceRow {
                            required property var modelData

                            label: modelData.description
                            detail: modelData.name
                            glyph: "microphone"
                            current: Audio.source?.id === modelData.id
                            currentSpoken: qsTr(", current input")
                            onActivated: Audio.setAudioSource(modelData)
                        }
                    }

                    SettingRow {
                        visible: Audio.sources.length === 0
                        label: qsTr("No input devices found")
                        description: qsTr("PipeWire reported no sources.")
                    }
                }

                ChannelPanel {
                    title: qsTr("Applications")
                    readout: Audio.streams.length > 0 ? qsTr("%1 playing").arg(Audio.streams.length) : ""

                    Repeater {
                        model: root.zeroVolumeStreams

                        delegate: SettingRow {
                            id: zeroVolRow

                            required property var modelData
                            readonly property string streamLabel: modelData.app_name || modelData.name || qsTr("Audio stream")

                            label: qsTr("%1 is at 0% volume").arg(streamLabel)
                            description: qsTr("Restore volume to 100% without changing mute state.")

                            StyledText {
                                text: qsTr("0% alert")
                                mono: true
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.signal
                            }

                            TextButton {
                                text: qsTr("Restore 100%")
                                Accessible.name: qsTr("Restore %1 volume to 100%").arg(zeroVolRow.streamLabel)
                                disabled: root.routingBusy
                                onClicked: root.fixStreamVolume(zeroVolRow.modelData.id)
                            }
                        }
                    }

                    Repeater {
                        model: Audio.streams

                        delegate: StreamLevel {
                            required property var modelData

                            name: Audio.getStreamName(modelData)
                            glyph: "apps"
                            available: !!modelData?.audio
                            level: Audio.getStreamVolume(modelData)
                            muted: Audio.getStreamMuted(modelData)
                            sliderName: qsTr("Volume for %1").arg(Audio.getStreamName(modelData))
                            muteName: qsTr("Mute %1").arg(Audio.getStreamName(modelData))
                            onLevelMoved: value => Audio.setStreamVolume(modelData, value)
                            onMuteToggled: muted => Audio.setStreamMuted(modelData, muted)
                        }
                    }

                    Repeater {
                        model: (root.routingAvailable && root.routingSinks.length > 1) ? root.routingStreams : []

                        delegate: SettingRow {
                            id: streamRouteRow

                            required property var modelData
                            readonly property string streamLabel: modelData.app_name || modelData.name || streamRouteRow.modelData.id

                            label: qsTr("Route %1").arg(streamLabel)
                            description: qsTr("Current output: %1").arg(root.sinkLabel(modelData.sink))

                            below: Flow {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                Repeater {
                                    model: root.routingSinks

                                    delegate: ToggleButton {
                                        required property var modelData

                                        readonly property string targetSink: modelData.name || modelData.id
                                        readonly property bool isCurrentSink: streamRouteRow.modelData.sink === targetSink

                                        toggled: isCurrentSink
                                        label: modelData.description || targetSink
                                        accent: "signal"
                                        horizontalPadding: Appearance.padding.normal
                                        verticalPadding: Appearance.padding.smaller
                                        disabled: root.routingBusy || isCurrentSink
                                        onClicked: root.moveStreamToSink(streamRouteRow.modelData.id, targetSink)
                                    }
                                }
                            }
                        }
                    }

                    SettingRow {
                        visible: Audio.streams.length === 0 && root.routingStreams.length === 0
                        label: qsTr("No applications currently playing audio")
                    }

                    SettingRow {
                        label: qsTr("Stream routing")
                        description: root.routingError.length > 0
                            ? root.routingError
                            : (root.routingAvailable
                                ? qsTr("Route active streams between headphones and virtual Studio sinks.")
                                : qsTr("Live stream routing is unavailable (is horneroctl updated?)."))

                        TextButton {
                            text: qsTr("Refresh")
                            Accessible.name: qsTr("Refresh audio stream routing")
                            type: TextButton.Tonal
                            disabled: root.routingBusy
                            onClicked: root.refreshRouting()
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
