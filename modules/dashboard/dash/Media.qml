pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import Quickshell
import QtQuick
import QtQuick.Layouts

// Playback strip: cover well, track identity, transport and a segmented
// position meter with timecode. Reads the active MPRIS player only; with
// none it says so and offers nothing to press (no bundled animation, no
// idle motion).
Item {
    id: root

    required property PersistentProperties visibilities

    readonly property var player: Players.active
    readonly property bool hasPlayer: !!player
    readonly property bool timed: hasPlayer && (player.length ?? -1) > 0
    readonly property real progress: timed ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function timecode(seconds: real): string {
        if (!(seconds >= 0))
            return "—:——";
        const hours = Math.floor(seconds / 3600);
        const mins = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60).toString().padStart(2, "0");
        return hours > 0 ? `${hours}:${mins.toString().padStart(2, "0")}:${secs}` : `${mins}:${secs}`;
    }

    Timer {
        running: root.hasPlayer && (root.player.isPlaying ?? false) && root.visibilities.dashboard
        interval: Config.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    implicitHeight: deck.implicitHeight

    RowLayout {
        id: deck

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        Instruments.Well {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            Layout.alignment: Qt.AlignVCenter
            clip: true

            Glyph {
                anchors.centerIn: parent

                name: root.hasPlayer ? "playlist" : "music-off"
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.large
            }

            Image {
                anchors.fill: parent
                anchors.margins: 1

                source: root.player?.trackArtUrl ?? "" // qmllint disable incompatible-type
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 280
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true

                text: root.hasPlayer ? ((root.player.trackTitle ?? "") || qsTr("Unknown title")) : qsTr("Nothing playing")
                color: Signal.palette.ink
                font.pointSize: Appearance.font.size.normal
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true

                text: root.hasPlayer ? ((root.player.trackArtist ?? "") || qsTr("Unknown artist")) : qsTr("Start playback in any media app to control it here.")
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            Instruments.Eyebrow {
                Layout.fillWidth: true

                visible: root.hasPlayer
                label: root.hasPlayer ? Players.getIdentity(root.player) + (root.player.isPlaying ? "" : " \u00b7 " + qsTr("paused")) : ""
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Transport {
                glyph: "player-skip-back"
                name: qsTr("Previous track")
                usable: root.player?.canGoPrevious ?? false

                function onClicked(): void {
                    root.player?.previous();
                }
            }

            Transport {
                glyph: root.player?.isPlaying ? "player-pause" : "player-play"
                name: root.player?.isPlaying ? qsTr("Pause") : qsTr("Play")
                usable: root.player?.canTogglePlaying ?? false
                lit: root.player?.isPlaying ?? false

                function onClicked(): void {
                    root.player?.togglePlaying();
                }
            }

            Transport {
                glyph: "player-skip-forward"
                name: qsTr("Next track")
                usable: root.player?.canGoNext ?? false

                function onClicked(): void {
                    root.player?.next();
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            Item {
                id: meterBox

                Layout.fillWidth: true
                implicitHeight: 12

                Instruments.SegmentMeter {
                    count: Math.max(8, Math.floor((meterBox.width + 2) / 5))
                    segmentWidth: 3
                    segmentLength: 12
                    gap: 2
                    value: root.progress
                    available: root.timed
                    threshold: 2
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    mono: true
                    text: root.timecode(root.timed ? root.player.position : -1)
                    color: Signal.palette.ink
                    font.pointSize: Appearance.font.size.small
                    font.features: {
                        "tnum": 1
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    mono: true
                    text: root.timecode(root.timed ? root.player.length : -1)
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    font.features: {
                        "tnum": 1
                    }
                }
            }
        }
    }

    component Transport: Rectangle {
        id: btn

        required property string glyph
        required property string name
        required property bool usable
        property bool lit: false

        function onClicked(): void {
        }

        implicitWidth: 36
        implicitHeight: 36
        radius: Appearance.rounding.small
        color: btn.lit ? Signal.palette.signalWell : Signal.palette.lifted
        border.width: 1
        border.color: btn.lit ? Signal.palette.signal : Signal.palette.rule
        opacity: btn.usable ? 1 : 0.5

        Accessible.role: Accessible.Button
        Accessible.name: btn.name

        StateLayer {
            disabled: !btn.usable
            radius: parent.radius
            color: btn.lit ? Signal.palette.onSignalWell : Signal.palette.ink

            function onClicked(): void {
                btn.onClicked();
            }
        }

        Glyph {
            anchors.centerIn: parent

            name: btn.glyph
            color: btn.lit ? Signal.palette.onSignalWell : btn.usable ? Signal.palette.ink : Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.large
        }
    }
}
