import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Media controls: prev / play-pause / next and the
// current track. Collapses to nothing while no player is active.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

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

    // Read by the bar: an idle transport leaves no segment, padding or rule.
    readonly property bool available: active
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
            icon: "player-skip-back"
            label: qsTr("Previous track")
            iconSize: Density.iconPt
            onActivated: root.player?.previous()
        }

        BarButton {
            icon: root.player?.isPlaying ? "player-pause" : "player-play"
            label: root.player?.isPlaying ? qsTr("Pause") : qsTr("Play")
            colour: root.tone.signal
            filled: true
            onActivated: root.player?.togglePlaying()
        }

        BarButton {
            visible: !root.vertical && (root.player?.canGoNext ?? false)
            icon: "player-skip-forward"
            label: qsTr("Next track")
            iconSize: Density.iconPt
            onActivated: root.player?.next()
        }

        StyledText {
            visible: !root.vertical && root.title !== ""
            Layout.leftMargin: Appearance.spacing.small
            Layout.maximumWidth: root.maxTitleWidth
            text: root.title
            elide: Text.ElideRight
            color: root.tone.inkMuted
            font.pointSize: Density.textPt
        }
    }
}
