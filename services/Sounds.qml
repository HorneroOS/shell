pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import "sounds.js" as Model

// Event sounds (Control Center > Notifications > Sounds). Default OFF. Plays a
// short freedesktop sound-theme file through PipeWire's pw-play. The policy
// (quiet modes, notification hints, rate limit, theme fallback) lives in
// sounds.js; this singleton owns one process per event kind, so a burst can
// never stack overlapping players.
Singleton {
    id: root

    readonly property real volume: Math.max(0, Math.min(1, Config.sounds.volume))

    // Installed sound themes (a directory with index.theme or the stereo
    // file we play first), refreshed on demand by the Sounds panel.
    property var themes: []

    // Result of the last Test: "" (played), "no-file", "no-player", "failed",
    // or "playing" while it runs.
    property string previewStatus: ""

    property var _last: ({})

    // Plays the first existing candidate; exit 4 = no pw-play, 3 = no file.
    // Paths are positional arguments, never interpolated into the script.
    readonly property string _script: "command -v pw-play >/dev/null 2>&1 || exit 4; v=$1; shift; for f in \"$@\"; do if [ -f \"$f\" ]; then exec pw-play --volume=\"$v\" \"$f\"; fi; done; exit 3"

    function _command(event: string): var {
        return ["sh", "-c", root._script, "hornero-sound", root.volume.toFixed(2)].concat(Model.candidates(Config.sounds.theme, event));
    }

    function _proc(event: string): var {
        return event === "notification" ? notificationProc : event === "battery" ? batteryProc : event === "charger" ? chargerProc : null;
    }

    // `quiet`: DND or held popups. `critical`: a critical battery warning,
    // which may chime through DND. `hints`: the notification's hints.
    // Returns "" when it plays, otherwise the reason it stayed silent.
    function play(event: string, quiet: bool, critical: bool, hints: var): string {
        const now = Date.now();
        const d = Model.decide(event, {
            enabled: Config.sounds.enabled,
            eventOn: !!Config.sounds.events[event],
            quiet: quiet,
            critical: critical,
            hints: hints,
            alwaysChime: Config.sounds.alwaysChime,
            now: now,
            last: root._last[event] ?? 0
        });
        if (!d.play)
            return d.reason;
        const proc = root._proc(event);
        if (!proc || proc.running)
            return "busy";
        root._last[event] = now;
        proc.command = root._command(event);
        proc.running = true;
        return "";
    }

    // Plays regardless of the enabled/quiet gates (the "Test" button) and
    // reports what happened in previewStatus.
    function preview(event: string): void {
        if (previewProc.running)
            return;
        root.previewStatus = "playing";
        previewProc.command = root._command(event);
        previewProc.running = true;
    }

    function refreshThemes(): void {
        if (!themeProc.running)
            themeProc.running = true;
    }

    Process {
        id: notificationProc
    }

    Process {
        id: batteryProc
    }

    Process {
        id: chargerProc
    }

    Process {
        id: previewProc

        onExited: exitCode => root.previewStatus = Model.exitReason(exitCode)
    }

    Process {
        id: themeProc

        command: ["sh", "-c", "for d in /usr/share/sounds/*/; do if [ -f \"${d}index.theme\" ] || [ -f \"${d}stereo/message-new-instant.oga\" ]; then basename \"$d\"; fi; done; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: root.themes = text.split("\n").map(s => Model.cleanTheme(s.trim())).filter(s => s.length > 0)
        }
    }
}
