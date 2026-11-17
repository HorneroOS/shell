pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import Hornero.Services
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Media tab (Signal Bezel): the playback strip at full size. Cover well,
// identity, transport, a segmented seek meter with timecode, and a
// spectrum well drawn from the real audio spectrum (cava). With no player
// the deck says so, disables its controls and draws an empty spectrum.
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

    implicitWidth: 968
    implicitHeight: frame.implicitHeight

    Timer {
        running: root.hasPlayer && (root.player.isPlaying ?? false) && root.visibilities.dashboard
        interval: Config.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    ServiceRef {
        service: Audio.cava
    }

    Instruments.Frame {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: headerHeight + (root.hasPlayer ? deck.implicitHeight : idle.implicitHeight) + 16
        channel: "01"
        title: qsTr("Playback")
        context: root.hasPlayer ? Players.getIdentity(root.player) : qsTr("No player")

        // No player: one honest line instead of an empty deck.
        RowLayout {
            id: idle

            anchors.left: parent.left
            anchors.right: parent.right
            visible: !root.hasPlayer
            spacing: Appearance.spacing.normal

            Glyph {
                name: "music-off"
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.larger
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Nothing playing. Start a player and its controls appear here.")
                color: Signal.palette.inkMuted
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: deck

            visible: root.hasPlayer
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.large

            Instruments.Well {
                Layout.preferredWidth: 176
                Layout.preferredHeight: 176
                Layout.alignment: Qt.AlignTop
                clip: true

                Glyph {
                    anchors.centerIn: parent

                    name: root.hasPlayer ? "playlist" : "music-off"
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.extraLarge
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
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true

                    text: root.hasPlayer ? ((root.player.trackTitle ?? "") || qsTr("Unknown title")) : qsTr("Nothing playing")
                    color: Signal.palette.ink
                    font.pointSize: Appearance.font.size.large
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true

                    text: root.hasPlayer ? ((root.player.trackArtist ?? "") || qsTr("Unknown artist")) : qsTr("Start playback in any media app to control it here.")
                    color: Signal.palette.inkMuted
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true

                    visible: root.hasPlayer && !!root.player.trackAlbum
                    text: root.player?.trackAlbum ?? ""
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.topMargin: Appearance.spacing.small
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

                    Item {
                        Layout.fillWidth: true
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "arrow-bar-up"
                        accessibleName: qsTr("Raise player")
                        inactiveOnColour: Signal.palette.cue
                        disabled: !root.player?.canRaise
                        onClicked: {
                            root.player?.raise();
                            root.visibilities.dashboard = false;
                        }
                    }

                    SplitButton {
                        id: playerSelector

                        disabled: !Players.list.length
                        active: menuItems.find(m => m.modelData === Players.active) ?? menuItems[0] ?? null
                        menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

                        menuItems: playerList.instances
                        fallbackIcon: "music-off"
                        fallbackText: qsTr("No players")

                        label.Layout.maximumWidth: 120
                        label.elide: Text.ElideRight

                        stateLayer.disabled: true
                        menuOnTop: true

                        Variants {
                            id: playerList

                            model: Players.list

                            PlayerItem {}
                        }
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "trash"
                        accessibleName: qsTr("Quit player")
                        inactiveOnColour: Signal.palette.alert
                        disabled: !root.player?.canQuit
                        onClicked: root.player?.quit()
                    }
                }

                // Seek: a segmented meter you can click, drag or step.
                Item {
                    id: seekBox

                    Layout.fillWidth: true
                    implicitHeight: 12

                    Instruments.SegmentSlider {
                        id: seek

                        anchors.fill: parent
                        vertical: false
                        count: Math.max(8, Math.floor((seekBox.width + 2) / 5))
                        segmentLength: 12
                        threshold: 2
                        stepSize: 0.02
                        accessibleName: qsTr("Playback position")
                        enabled: root.timed && (root.player.canSeek ?? false) && (root.player.positionSupported ?? false)
                        value: root.progress
                        onMoved: v => {
                            const active = Players.active;
                            if (active?.canSeek && active?.positionSupported && active.length > 0)
                                active.position = Math.max(0, Math.min(1, v)) * active.length;
                        }
                    }

                    CustomMouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton

                        function onWheel(event: WheelEvent) {
                            const active = Players.active;
                            if (!active?.canSeek || !active?.positionSupported)
                                return;

                            event.accepted = true;
                            const delta = event.angleDelta.y > 0 ? 10 : -10;
                            Qt.callLater(() => {
                                active.position = Math.max(0, Math.min(active.length, active.position + delta));
                            });
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        mono: true
                        text: root.timecode(root.timed ? root.player.position : -1)
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

                // Spectrum: one column of 3 px segments per cava band.
                Instruments.Well {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    clip: true

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        Repeater {
                            model: Config.services.visualiserBars

                            Item {
                                id: band

                                required property int index
                                readonly property real level: Math.max(0, Math.min(1, Audio.cava.values[index] ?? 0))

                                width: Math.max(2, (parent.width - (Config.services.visualiserBars - 1) * 2) / Config.services.visualiserBars)
                                height: parent.height

                                Instruments.SegmentMeter {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    vertical: true
                                    count: Math.max(1, Math.floor((band.height + 2) / 5))
                                    segmentWidth: 3
                                    segmentLength: band.width
                                    gap: 2
                                    value: band.level
                                    available: root.hasPlayer && (root.player.isPlaying ?? false)
                                    onColor: Signal.palette.phosphor
                                    threshold: 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData)
        activeIcon: "gif"
    }

    component Transport: Rectangle {
        id: btn

        required property string glyph
        required property string name
        required property bool usable
        property bool lit: false

        function onClicked(): void {
        }

        implicitWidth: 40
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
