pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Lock media footer: what is playing and the three transport controls.
// Hidden entirely when there is no player.
RowLayout {
    id: root

    required property var lock
    readonly property bool active: !!Players.active

    spacing: Appearance.spacing.normal

    Rectangle {
        implicitWidth: 40
        implicitHeight: 40
        radius: Appearance.rounding.small
        color: Signal.palette.sunken
        border.width: 1
        border.color: Signal.palette.rule
        clip: true

        Glyph {
            anchors.centerIn: parent

            name: "playlist"
            color: Signal.palette.inkMuted
        }

        Image {
            anchors.fill: parent
            anchors.margins: 1

            source: Players.active?.trackArtUrl ?? "" // qmllint disable incompatible-type
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width
            sourceSize.height: height
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            Layout.fillWidth: true

            text: (Players.active?.trackTitle ?? "") || qsTr("Unknown title")
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true

            text: (Players.active?.trackArtist ?? "") || qsTr("Unknown artist")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }

    Control {
        glyph: "player-skip-back"
        name: qsTr("Previous track")
        usable: Players.active?.canGoPrevious ?? false

        function onClicked(): void {
            Players.active?.previous();
        }
    }

    Control {
        glyph: Players.active?.isPlaying ? "player-pause" : "player-play"
        name: Players.active?.isPlaying ? qsTr("Pause") : qsTr("Play")
        usable: Players.active?.canTogglePlaying ?? false

        function onClicked(): void {
            Players.active?.togglePlaying();
        }
    }

    Control {
        glyph: "player-skip-forward"
        name: qsTr("Next track")
        usable: Players.active?.canGoNext ?? false

        function onClicked(): void {
            Players.active?.next();
        }
    }

    component Control: Rectangle {
        id: ctl

        required property string glyph
        required property string name
        required property bool usable

        function onClicked(): void {
        }

        implicitWidth: 32
        implicitHeight: 32
        radius: Appearance.rounding.small
        color: Signal.palette.lifted
        border.width: 1
        border.color: Signal.palette.rule
        opacity: ctl.usable ? 1 : 0.5

        Accessible.role: Accessible.Button
        Accessible.name: ctl.name

        StateLayer {
            disabled: !ctl.usable
            radius: parent.radius

            function onClicked(): void {
                ctl.onClicked();
            }
        }

        Glyph {
            anchors.centerIn: parent

            name: ctl.glyph
            color: ctl.usable ? Signal.palette.ink : Signal.palette.inkMuted
        }
    }
}
