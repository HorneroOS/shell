pragma Singleton

import qs.services as Services
import QtQuick

QtObject {
    readonly property bool hasPlayer: Services.Players.active !== null && Services.Players.active !== undefined
    readonly property string identity: hasPlayer ? Services.Players.getIdentity(Services.Players.active) : ""
    readonly property string title: Services.Players.active?.trackTitle ?? ""
    readonly property string artist: Services.Players.active?.trackArtist ?? ""
    readonly property bool isPlaying: Services.Players.active?.isPlaying ?? false

    // Transport is user-initiated only: plugins call these from their
    // own interaction handlers; nothing here auto-plays on load.
    function playPause(): void {
        const active = Services.Players.active;
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function previous(): void {
        const active = Services.Players.active;
        if (active?.canGoPrevious)
            active.previous();
    }

    function next(): void {
        const active = Services.Players.active;
        if (active?.canGoNext)
            active.next();
    }
}
