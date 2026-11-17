pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
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

                    SettingRow {
                        visible: Audio.streams.length === 0
                        label: qsTr("No applications currently playing audio")
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
