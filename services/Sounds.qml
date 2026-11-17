pragma Singleton

import qs.config
import Quickshell
import QtQuick

// Event sounds (Control Center > Notifications > Sounds). Default OFF. Plays a
// short freedesktop sound-theme file through PipeWire's pw-play; quiet when
// the experience mode holds popups (Focus, Gaming) or Do Not Disturb is on.
Singleton {
    id: root

    // event id -> sound-theme file name
    readonly property var files: ({
            "notification": "message-new-instant",
            "battery": "dialog-warning",
            "charger": "power-plug"
        })
    readonly property real volume: Math.max(0, Math.min(1, Config.sounds.volume))

    function pathFor(event: string): string {
        const name = root.files[event];
        const theme = String(Config.sounds.theme).replace(/[^A-Za-z0-9_.-]/g, "");
        if (!name || theme.length === 0)
            return "";
        return `/usr/share/sounds/${theme}/stereo/${name}.oga`;
    }

    // `quiet` is passed by callers that know about DND / held popups.
    function play(event: string, quiet: bool): void {
        if (!Config.sounds.enabled || quiet || !Config.sounds.events[event])
            return;
        root.preview(event);
    }

    // Plays regardless of the enabled/quiet gates (the "Test" button).
    function preview(event: string): void {
        const path = root.pathFor(event);
        if (path.length === 0)
            return;
        Quickshell.execDetached(["pw-play", "--volume=" + root.volume.toFixed(2), path]);
    }
}
