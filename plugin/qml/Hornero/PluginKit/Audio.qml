pragma Singleton

import qs.services as Services
import QtQuick

QtObject {
    readonly property real volume: Services.Audio.volume
    readonly property bool muted: Services.Audio.muted
    readonly property real sourceVolume: Services.Audio.sourceVolume
    readonly property bool sourceMuted: Services.Audio.sourceMuted
    readonly property bool hasSink: Services.Audio.sink !== null && Services.Audio.sink !== undefined
    readonly property bool hasSource: Services.Audio.source !== null && Services.Audio.source !== undefined

    // Audio controls are user-initiated only: plugins call these from
    // their own interaction handlers; nothing here changes volume on load.
    function setVolume(v: real): void {
        Services.Audio.setVolume(v);
    }

    function incrementVolume(): void {
        Services.Audio.incrementVolume(0);
    }

    function decrementVolume(): void {
        Services.Audio.decrementVolume(0);
    }

    function toggleMute(): void {
        if (Services.Audio.sink && Services.Audio.sink.audio)
            Services.Audio.sink.audio.muted = !Services.Audio.muted;
    }

    function toggleSourceMute(): void {
        if (Services.Audio.source && Services.Audio.source.audio)
            Services.Audio.source.audio.muted = !Services.Audio.sourceMuted;
    }
}
