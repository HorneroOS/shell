import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Media controls: prev / play-pause / next and the
// current track. Collapses to nothing while no player is active.
Item {
    id: root

    property bool vertical
    property var options: ({})
    readonly property var player: Players.active
    readonly property bool active: player !== null && (player.playbackState === 1 || player.playbackState === 2 || (options.showWhenIdle ?? false))
    readonly property int maxTitleWidth: options.maxWidth ?? 280
    readonly property string title: {
        if (!player)
            return "";
        const t = player.trackTitle || qsTr("Unknown title");
        const a = player.trackArtist;
        return a ? `${t} — ${a}` : t;
    }

    visible: active
    implicitWidth: active ? layout.implicitWidth : 0
    implicitHeight: active ? layout.implicitHeight : 0

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: 0

        BarButton {
            visible: !root.vertical && (root.player?.canGoPrevious ?? false)
            icon: "skip_previous"
            label: qsTr("Previous track")
            iconSize: Appearance.font.size.normal
            onActivated: root.player?.previous()
        }

        BarButton {
            icon: root.player?.isPlaying ? "pause" : "play_arrow"
            label: root.player?.isPlaying ? qsTr("Pause") : qsTr("Play")
            colour: Colours.palette.m3primary
            filled: true
            onActivated: root.player?.togglePlaying()
        }

        BarButton {
            visible: !root.vertical && (root.player?.canGoNext ?? false)
            icon: "skip_next"
            label: qsTr("Next track")
            iconSize: Appearance.font.size.normal
            onActivated: root.player?.next()
        }

        StyledText {
            visible: !root.vertical && root.title !== ""
            Layout.leftMargin: Appearance.spacing.small
            Layout.maximumWidth: root.maxTitleWidth
            text: root.title
            elide: Text.ElideRight
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
        }
    }
}
