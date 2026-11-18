import Quickshell.Io

// Event sounds. Off by default: HorneroOS is quiet until you ask. Sounds come
// from an installed freedesktop sound theme and play through PipeWire
// (pw-play); nothing is bundled or downloaded.
JsonObject {
    property bool enabled: false
    // 0..1 playback volume.
    property real volume: 0.5
    // Directory name under /usr/share/sounds (freedesktop is the standard theme).
    property string theme: "freedesktop"
    // Chime even when an app names its own sound (sound-name / sound-file
    // hints); off by default so apps that play their own are not doubled.
    property bool alwaysChime: false
    property Events events: Events {}

    component Events: JsonObject {
        property bool notification: true
        property bool battery: true
        property bool charger: true
    }
}
