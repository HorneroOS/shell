pragma Singleton

import qs.services as Services
import QtQuick

// Audio state from the shell's PipeWire service (provider domain
// "audio", event-driven). Volume/mute controls are user-initiated only:
// call them from an interaction handler, never on load.
//
// `spectrum` is the shared visualiser analysis of the default output
// (provider domain "spectrum"): one value per band, 0–1, real PipeWire
// data. It runs only while some surface holds a "spectrum" lease, and is
// all zeros when nothing is playing.
QtObject {
    readonly property real volume: Services.Audio.volume
    readonly property bool muted: Services.Audio.muted
    readonly property real sourceVolume: Services.Audio.sourceVolume
    readonly property bool sourceMuted: Services.Audio.sourceMuted
    readonly property bool hasSink: Services.Audio.sink !== null && Services.Audio.sink !== undefined
    readonly property bool hasSource: Services.Audio.source !== null && Services.Audio.source !== undefined
    readonly property string outputName: Services.Audio.sink?.description || Services.Audio.sink?.name || ""
    readonly property string inputName: Services.Audio.source?.description || Services.Audio.source?.name || ""
    // Application playback/record streams currently known to PipeWire.
    readonly property int streamCount: Services.Audio.streams.length
    readonly property var spectrum: Services.Audio.cava.values

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
