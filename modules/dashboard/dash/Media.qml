pragma ComponentBehavior: Bound

import qs.components
import qs.components.motion
import qs.services
import qs.config
import qs.modules.companion
import qs.modules.instruments as Instruments
import Hornero.Internal
import Hornero.Services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Media deck (Signal Bezel; Caelestia-recovery item 5, re-implemented as a
// cassette deck / mixer channel, not cover art). A sunken square cover well
// flanked by the stereo spectrum: the left channel grows out to the left,
// the right channel to the right, lowest band at the bottom, 3 px `phosphor`
// segments, the hot zone in `signal` amber and an amber peak-hold tick per
// band. Below: identity, transport, and a tape-counter timecode over the
// segmented seek meter. Reads the active MPRIS player only.
//
// With no player the deck says NO SIGNAL, the columns stay dark and Javi
// dozes in the well (needs the mascot; dashboard.media.javi). Nothing
// moves while idle: the spectrum sleeps and the sampler is released.
//
// `layout`: "strip" (one row, the classic home grid) or "tower" (tall hero
// cell of the console composition).
Item {
    id: root

    required property PersistentProperties visibilities
    property string layout: "strip"

    readonly property bool tower: layout === "tower"
    readonly property var player: Players.active
    readonly property bool hasPlayer: !!player
    readonly property bool playing: hasPlayer && (player.isPlaying ?? false)
    readonly property bool timed: hasPlayer && (player.length ?? -1) > 0
    readonly property real progress: timed ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    readonly property var media: Config.dashboard.media
    // The spectrum is motion: it is drawn only when motion is not off.
    readonly property bool spectrumOn: media.spectrum && Choreography.animated
    readonly property int bands: Math.max(8, Math.min(24, media.bands))
    readonly property bool dozing: !hasPlayer && media.javi && Atmosphere.mascot

    function timecode(seconds: real): string {
        if (!(seconds >= 0))
            return "--:--";
        const hours = Math.floor(seconds / 3600);
        const mins = Math.floor((seconds % 3600) / 60).toString().padStart(2, "0");
        const secs = Math.floor(seconds % 60).toString().padStart(2, "0");
        return hours > 0 ? `${hours}:${mins}:${secs}` : `${mins}:${secs}`;
    }

    implicitWidth: tower ? 300 : 640
    implicitHeight: tower ? towerLayout.implicitHeight : 60

    Timer {
        running: root.playing && root.visibilities.dashboard
        interval: Config.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    // Sample stereo audio only while something plays and the deck is shown.
    ServiceRef {
        service: root.playing && root.spectrumOn && root.visibilities.dashboard ? Audio.cavaStereo : null
    }

    // --- strip: one row ------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        visible: !root.tower
        spacing: Appearance.spacing.normal

        DeckWell {
            Layout.preferredHeight: 56
            Layout.preferredWidth: implicitWidth
            Layout.alignment: Qt.AlignVCenter
            cover: 56
            column: 36
        }

        Identity {
            Layout.fillWidth: false
            Layout.preferredWidth: 240
            Layout.alignment: Qt.AlignVCenter
        }

        TransportRow {
            Layout.alignment: Qt.AlignVCenter
        }

        SeekBlock {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // --- tower: tall hero ----------------------------------------------------
    ColumnLayout {
        id: towerLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.tower
        spacing: Appearance.spacing.normal

        DeckWell {
            readonly property real side: Math.max(40, Math.round(towerLayout.width * 0.17))

            Layout.fillWidth: true
            Layout.preferredHeight: cover
            column: side
            cover: Math.min(184, Math.max(96, towerLayout.width - 2 * side - 2 * Appearance.spacing.small))
        }

        Identity {
            Layout.fillWidth: true
        }

        SeekBlock {
            Layout.fillWidth: true
        }

        TransportRow {
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Cover well with the L/R spectrum columns on either side.
    component DeckWell: Item {
        id: well

        required property real cover
        required property real column

        implicitWidth: cover + 2 * column + 2 * Appearance.spacing.small
        implicitHeight: cover

        Instruments.Spectrum {
            id: leftColumn

            anchors.right: coverWell.left
            anchors.rightMargin: Appearance.spacing.small
            anchors.verticalCenter: coverWell.verticalCenter
            width: well.column
            height: well.cover

            visible: root.spectrumOn
            values: Audio.cavaStereo.values
            sliceStart: 0
            sliceLength: root.bands
            active: root.playing
            direction: SpectrumMeter.Left
            reversed: true
            offColor: Signal.palette.rule
            peakHold: root.media.peakHold
            bandGap: root.tower ? 2 : 1
            Accessible.name: qsTr("Left channel spectrum")
        }

        Instruments.Well {
            id: coverWell

            anchors.centerIn: parent
            width: well.cover
            height: well.cover
            clip: true

            Image {
                id: art

                anchors.fill: parent
                anchors.margins: 1

                visible: root.hasPlayer && status === Image.Ready
                source: root.player?.trackArtUrl ?? "" // qmllint disable incompatible-type
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                Accessible.ignored: true
            }

            Glyph {
                anchors.centerIn: parent

                visible: root.hasPlayer && !art.visible
                name: "playlist"
                color: Signal.palette.inkMuted
                font.pointSize: root.tower ? Appearance.font.size.extraLarge : Appearance.font.size.large
            }

            // No player: a dark well that says so, Javi asleep in it.
            Column {
                anchors.centerIn: parent

                visible: !root.hasPlayer
                spacing: root.tower ? Appearance.spacing.small : 0

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter

                    visible: root.dozing
                    width: root.tower ? Math.round(well.cover * 0.5) : Math.round(well.cover * 0.62)
                    height: width
                    source: root.dozing ? Companion.resolve(CompanionStore.effectiveSkin, "sleep").file : ""
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    Accessible.ignored: true
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    visible: root.tower
                    mono: true
                    text: qsTr("NO SIGNAL")
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    font.letterSpacing: Appearance.font.size.small * 0.12
                    Accessible.role: Accessible.StaticText
                    Accessible.name: qsTr("No signal: nothing is playing")
                }
            }
        }

        Instruments.Spectrum {
            anchors.left: coverWell.right
            anchors.leftMargin: Appearance.spacing.small
            anchors.verticalCenter: coverWell.verticalCenter
            width: well.column
            height: well.cover

            visible: root.spectrumOn
            values: Audio.cavaStereo.values
            sliceStart: root.bands
            sliceLength: root.bands
            active: root.playing
            direction: SpectrumMeter.Right
            reversed: true
            offColor: Signal.palette.rule
            peakHold: root.media.peakHold
            bandGap: leftColumn.bandGap
            Accessible.name: qsTr("Right channel spectrum")
        }
    }

    component Identity: ColumnLayout {
        spacing: 2

        StyledText {
            Layout.fillWidth: true

            text: root.hasPlayer ? ((root.player.trackTitle ?? "") || qsTr("Unknown title")) : qsTr("Nothing playing")
            color: Signal.palette.ink
            font.pointSize: root.tower ? Appearance.font.size.larger : Appearance.font.size.normal
            font.weight: Font.Medium
            elide: Text.ElideRight
            horizontalAlignment: root.tower ? Text.AlignHCenter : Text.AlignLeft
        }

        StyledText {
            Layout.fillWidth: true

            text: root.hasPlayer ? ((root.player.trackArtist ?? "") || qsTr("Unknown artist")) : qsTr("Start playback in any media app to control it here.")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
            wrapMode: root.tower && !root.hasPlayer ? Text.WordWrap : Text.NoWrap
            horizontalAlignment: root.tower ? Text.AlignHCenter : Text.AlignLeft
        }

        // The player, or NO SIGNAL on the strip (the tower says it in the well).
        Instruments.Eyebrow {
            Layout.fillWidth: true

            visible: root.hasPlayer || !root.tower
            label: root.hasPlayer ? Players.getIdentity(root.player) + (root.player.isPlaying ? "" : " · " + qsTr("paused")) : qsTr("NO SIGNAL")
            horizontalAlignment: root.tower ? Text.AlignHCenter : Text.AlignLeft
        }
    }

    component TransportRow: RowLayout {
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

    // Tape counter over the segmented seek meter.
    component SeekBlock: ColumnLayout {
        spacing: 6

        TapeCounter {
            Layout.alignment: root.tower ? Qt.AlignHCenter : Qt.AlignLeft
        }

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
                Accessible.name: qsTr("Playback position")
            }
        }
    }

    // A tape-deck counter window: sunken, Plex Mono tabular digits, the
    // position in `ink` and the length in `inkMuted` ("03:14 / 05:02").
    component TapeCounter: Instruments.Well {
        id: counter

        readonly property string position: root.timecode(root.timed ? root.player.position : -1)
        readonly property string length: root.timecode(root.timed ? root.player.length : -1)

        implicitWidth: counterRow.implicitWidth + 12
        implicitHeight: counterRow.implicitHeight + 4

        Accessible.role: Accessible.StaticText
        Accessible.name: root.timed ? qsTr("Position %1 of %2").arg(counter.position).arg(counter.length) : qsTr("No position")

        Row {
            id: counterRow

            anchors.centerIn: parent
            spacing: 4

            StyledText {
                mono: true
                text: counter.position
                color: root.timed ? Signal.palette.ink : Signal.palette.inkFaint
                font.pointSize: Appearance.font.size.small
                font.features: {
                    "tnum": 1
                }
                Accessible.ignored: true
            }

            StyledText {
                mono: true
                text: "/"
                color: Signal.palette.inkFaint
                font.pointSize: Appearance.font.size.small
                Accessible.ignored: true
            }

            StyledText {
                mono: true
                text: counter.length
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
                font.features: {
                    "tnum": 1
                }
                Accessible.ignored: true
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
