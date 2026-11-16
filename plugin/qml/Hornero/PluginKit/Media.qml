pragma Singleton

import qs.services as Services
import QtQuick

// MPRIS playback from the shell's Players service (provider domain
// "media", event-driven). Transport functions are user-initiated only:
// nothing here auto-plays on load. Position/length are seconds; position
// is refreshed by the player, call `refreshPosition()` from a 1 s timer
// only while playing and visible.
QtObject {
    readonly property var _player: Services.Players.active
    readonly property bool hasPlayer: _player !== null && _player !== undefined
    readonly property string identity: hasPlayer ? Services.Players.getIdentity(_player) : ""
    readonly property string title: _player?.trackTitle ?? ""
    readonly property string artist: _player?.trackArtist ?? ""
    readonly property string album: _player?.trackAlbum ?? ""
    readonly property string artUrl: _player?.trackArtUrl ?? ""
    readonly property bool isPlaying: _player?.isPlaying ?? false
    readonly property real position: _player?.position ?? 0
    readonly property real length: _player?.length ?? 0
    readonly property bool lengthSupported: (_player?.lengthSupported ?? false) && length > 0
    readonly property bool canGoNext: _player?.canGoNext ?? false
    readonly property bool canGoPrevious: _player?.canGoPrevious ?? false
    readonly property bool canTogglePlaying: _player?.canTogglePlaying ?? false

    function playPause(): void {
        if (_player?.canTogglePlaying)
            _player.togglePlaying();
    }

    function previous(): void {
        if (_player?.canGoPrevious)
            _player.previous();
    }

    function next(): void {
        if (_player?.canGoNext)
            _player.next();
    }

    function refreshPosition(): void {
        _player?.positionChanged();
    }
}
